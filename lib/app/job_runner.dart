import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
import '../platform/android/android_thermal_monitor.dart';
import '../services/blob_store.dart';
import '../services/dart_crypto_engine.dart';
import '../services/job_repository.dart';
import '../services/vault_repository.dart';

/// Simple cancellation token passed to [JobRunner.run].
class CancellationToken {
  bool _cancelled = false;

  /// Signals cancellation.  Safe to call multiple times.
  void cancel() => _cancelled = true;

  /// Returns true once [cancel] has been called.
  bool get isCancelled => _cancelled;
}

/// Snapshot of progress emitted by [JobRunner.run] after each processed item.
class JobProgress {
  const JobProgress({
    required this.completedItems,
    required this.totalItems,
    required this.processedBytes,
    required this.totalBytes,
    required this.currentFile,
  });

  final int completedItems;
  final int totalItems;
  final int processedBytes;
  final int totalBytes;
  final String currentFile;
}

/// Processes the pending [OperationJobItem]s for a single [OperationJob] one
/// at a time, emitting a [JobProgress] after each completed item.
///
/// On Android, pauses when the thermal status is [ThermalStatus.moderate] or
/// higher, retrying every 5 seconds until the device cools down.
class JobRunner {
  JobRunner({
    required this.blobStore,
    required this.crypto,
    required this.repo,
    required this.jobRepo,
    this.thermalMonitor,
  });

  final BlobStore blobStore;
  final DartCryptoEngine crypto;
  final VaultRepository repo;
  final JobRepository jobRepo;
  final AndroidThermalMonitor? thermalMonitor;

  /// Runs the job, yielding [JobProgress] after each item.
  ///
  /// Marks the job [JobState.running] before the first item and
  /// [JobState.completed] / [JobState.cancelled] / [JobState.failed] on exit.
  Stream<JobProgress> run(
    OperationJob job,
    Uint8List masterKey, {
    CancellationToken? token,
  }) async* {
    await jobRepo.markJobState(job.id, JobState.running);

    final items = await jobRepo.findPendingItems(job.id);

    var completedItems = job.completedItems;
    var processedBytes = job.processedBytes;

    for (final item in items) {
      // ------------------------------------------------------------------ //
      // Cancellation check
      // ------------------------------------------------------------------ //
      if (token?.isCancelled ?? false) {
        await jobRepo.markJobItemState(
          item.id,
          JobItemState.failed,
          failureReason: 'Cancelled by user',
        );
        await jobRepo.markJobState(job.id, JobState.cancelled);
        return;
      }

      // ------------------------------------------------------------------ //
      // Thermal throttle (Android only)
      // ------------------------------------------------------------------ //
      if (thermalMonitor != null && Platform.isAndroid) {
        while ((thermalMonitor!.currentStatus.index >=
            ThermalStatus.moderate.index)) {
          await Future<void>.delayed(const Duration(seconds: 5));
          // Check cancellation while waiting.
          if (token?.isCancelled ?? false) {
            await jobRepo.markJobItemState(
              item.id,
              JobItemState.failed,
              failureReason: 'Cancelled during thermal wait',
            );
            await jobRepo.markJobState(job.id, JobState.cancelled);
            return;
          }
        }
      }

      // ------------------------------------------------------------------ //
      // Process item
      // ------------------------------------------------------------------ //
      await jobRepo.markJobItemState(item.id, JobItemState.running);

      try {
        final partialPath = await blobStore.createPartialPath(item.blobId);

        final encryptResult = await crypto.encryptFile(
          sourcePath: item.sourcePath,
          destPath: partialPath,
          key: masterKey,
        );

        await blobStore.commitPartial(item.blobId);

        // Persist the VaultFile via the canonical addMedia path, which handles
        // the counter update in the same transaction.  We already have the
        // encrypted blob on disk so we pass the source file path so addMedia
        // can read its length, but we DON'T want it to re-encrypt — therefore
        // we need a lighter approach: write the VaultFile row directly.
        //
        // addMedia re-encrypts when given sourcePath, so we inline the DB write
        // instead to avoid double encryption.
        await repo.addEncryptedBlobRecord(
          originalName: path.basename(item.sourcePath),
          parentFolderId: item.parentFolderId,
          blobId: item.blobId,
          ivBase64: encryptResult.ivBase64,
          byteSize: encryptResult.byteSize,
        );

        await jobRepo.markJobItemState(item.id, JobItemState.completed);

        completedItems += 1;
        processedBytes += item.sourceSizeBytes;

        yield JobProgress(
          completedItems: completedItems,
          totalItems: job.totalItems,
          processedBytes: processedBytes,
          totalBytes: job.totalBytes,
          currentFile: item.sourcePath,
        );
      } catch (e) {
        await jobRepo.markJobItemState(
          item.id,
          JobItemState.failed,
          failureReason: e.toString(),
        );
        // Continue processing remaining items rather than aborting the job.
      }
    }

    await jobRepo.markJobState(job.id, JobState.completed);
  }
}
