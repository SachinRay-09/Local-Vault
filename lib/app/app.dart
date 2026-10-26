import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
import '../services/app_lifecycle_service.dart';
import '../services/archive_reader.dart';
import '../services/blob_store.dart';
import '../services/credential_repository.dart';
import '../services/dart_crypto_engine.dart';
import '../services/file_crypto_service.dart';
import '../services/job_repository.dart';
import '../services/secure_storage_service.dart';
import '../services/settings_service.dart';
import '../services/vault_repository.dart';
import '../ui/auth/auth_gate.dart';
import '../ui/home/home_screen.dart';
import '../ui/mobile/mobile_home_screen.dart';
import 'auth_session.dart';
import 'job_runner.dart';
import 'vault_theme.dart';

// ---------------------------------------------------------------------------
// Top-level helpers — must be outside all classes.
// ---------------------------------------------------------------------------

/// Generates a 32-hex-char blob ID using a cryptographically secure RNG.
/// Top-level so it can be called from non-State code during crash recovery.
String _appGenerateBlobId() {
  final r = Random.secure();
  return List<int>.generate(16, (_) => r.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}

// ---------------------------------------------------------------------------
// Enum used by the interrupted-jobs dialog
// ---------------------------------------------------------------------------

enum _RecoveryChoice { resume, discard }

// ---------------------------------------------------------------------------
// VaultApp
// ---------------------------------------------------------------------------

class VaultApp extends StatefulWidget {
  const VaultApp({super.key});

  /// Process-global theme notifier. Default: ThemeMode.system.
  /// Updated after first frame from persisted AppSettings.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> with WidgetsBindingObserver {
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;
  late final AppLifecycleService _lifecycleService;

  @override
  void initState() {
    super.initState();
    const seed = Color(0xFF5B5BD6);
    _lightTheme = buildVaultTheme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light));
    _darkTheme = buildVaultTheme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

    _lifecycleService = AppLifecycleService();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleService.initialize();

    // Three independent try/catch blocks so failure of any one block never
    // silences the others.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // (1) Theme load — defaults to system on failure.
      try {
        final raw = await SettingsService().getThemeMode();
        VaultApp.themeMode.value = parseThemeMode(raw);
      } catch (e) {
        debugPrint('[App] Theme load failed (defaulting to system): $e');
      }

      // (2) Crash recovery — interrupted jobs.
      try {
        await _checkInterruptedJobs();
      } catch (e) {
        debugPrint('[App] Interrupted jobs check failed: $e');
      }

      // (3) Rollback marker check — interrupted password change.
      try {
        await _checkRollbackMarker();
      } catch (e) {
        debugPrint('[App] Rollback marker check failed: $e');
      }
    });
  }

  @override
  void dispose() {
    try {
      _lifecycleService.performFinalCleanup();
    } catch (e) {
      debugPrint('Final cleanup error: $e');
    }

    WidgetsBinding.instance.removeObserver(this);
    _lifecycleService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleService.handleLifecycleChange(state);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VaultApp.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Local Vault',
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Crash recovery — _checkInterruptedJobs (Phase 6: Resume + Discard)
  // ---------------------------------------------------------------------------

  Future<void> _checkInterruptedJobs() async {
    if (!mounted) return;

    final jobRepo = JobRepository();
    final interrupted = await jobRepo.findInterruptedJobs();
    if (interrupted.isEmpty) return;

    // Collect items that have partial blobs on disk.
    final blobStore = BlobStore();
    final partialItems = <OperationJobItem>[];

    for (final job in interrupted) {
      final items = await jobRepo.findPendingOrRunningItems(job.id);
      for (final item in items) {
        final partial = item.partialBlobPath;
        if (partial != null && File(partial).existsSync()) {
          partialItems.add(item);
        }
      }
    }

    if (!mounted) return;
    if (partialItems.isEmpty) {
      // No partial blobs — just mark jobs as failed and move on.
      for (final job in interrupted) {
        await jobRepo.markJobState(job.id, JobState.failed);
      }
      return;
    }

    // Show dialog listing the interrupted items, offering Resume or Discard.
    final choice = await showDialog<_RecoveryChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InterruptedJobsDialog(
        jobs: interrupted,
        itemCount: partialItems.length,
      ),
    );

    if (choice == _RecoveryChoice.discard) {
      await _discardJobs(interrupted, partialItems, blobStore, jobRepo);
    } else if (choice == _RecoveryChoice.resume) {
      await _resumeJobs(interrupted, blobStore, jobRepo);
    }
    // null (dialog dismissed by system) → do nothing
  }

  // ---------------------------------------------------------------------------
  // Discard path — byte-for-byte identical to previous behaviour
  // ---------------------------------------------------------------------------

  Future<void> _discardJobs(
    List<OperationJob> jobs,
    List<OperationJobItem> partialItems,
    BlobStore blobStore,
    JobRepository jobRepo,
  ) async {
    for (final item in partialItems) {
      await blobStore.deleteBlobIfExists(item.blobId);
      await jobRepo.markJobItemState(item.id, JobItemState.skipped);
    }
    for (final job in jobs) {
      await jobRepo.markJobState(job.id, JobState.failed);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interrupted import data cleaned up.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Resume path
  // ---------------------------------------------------------------------------

  Future<void> _resumeJobs(
    List<OperationJob> jobs,
    BlobStore blobStore,
    JobRepository jobRepo,
  ) async {
    final session = AuthSession.current;
    if (session == null) return; // should not happen; post-auth gate
    for (final job in jobs) {
      await _resumeJob(job, session.dek, blobStore, jobRepo);
    }
  }

  Future<void> _resumeJob(
    OperationJob job,
    Uint8List masterKey,
    BlobStore blobStore,
    JobRepository jobRepo,
  ) async {
    if (!mounted) return;
    final sourcePath = job.sourceDescriptor;

    // Local closure — shows a non-dismissable 'source not found' dialog.
    Future<void> showSourceNotFoundDialog() async {
      if (!mounted) return;
      final truncated = sourcePath != null && sourcePath.length > 60
          ? '…${sourcePath.substring(sourcePath.length - 60)}'
          : sourcePath ?? '(unknown)';
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Source Not Found'),
          content: Text(
            'The original source files could not be found ($truncated). '
            'The interrupted import cannot be resumed. Discard it?',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final items = await jobRepo.findPendingOrRunningItems(job.id);
                for (final item in items) {
                  await blobStore.deleteBlobIfExists(item.blobId);
                  await jobRepo.markJobItemState(item.id, JobItemState.skipped);
                }
                await jobRepo.markJobState(job.id, JobState.failed);
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    }

    if (sourcePath == null) {
      await showSourceNotFoundDialog();
      return;
    }

    final isZip = sourcePath.toLowerCase().endsWith('.zip');

    if (isZip) {
      if (!File(sourcePath).existsSync()) {
        await showSourceNotFoundDialog();
        return;
      }
      await _resumeZipJob(job, masterKey, blobStore, jobRepo, sourcePath);
    } else {
      if (!Directory(sourcePath).existsSync()) {
        await showSourceNotFoundDialog();
        return;
      }
      await _resumeFolderJob(job, masterKey, blobStore, jobRepo);
    }
  }

  Future<void> _resumeFolderJob(
    OperationJob job,
    Uint8List masterKey,
    BlobStore blobStore,
    JobRepository jobRepo,
  ) async {
    if (!mounted) return;
    final repo = VaultRepository(
      crypto: const FileCryptoService(),
      secureStorage: SecureStorageService.instance,
    );
    final runner = JobRunner(
      blobStore: blobStore,
      crypto: DartCryptoEngine(),
      repo: repo,
      jobRepo: jobRepo,
      // thermalMonitor intentionally omitted on recovery path —
      // resume is a one-time operation and thermal pause adds complexity
      // that is not warranted for an occasional crash-recovery flow.
    );

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ResumeProgressDialog(
        runner: runner,
        job: job,
        masterKey: masterKey,
        onComplete: () {
          Navigator.pop(ctx);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => _getHomeScreen()),
            );
          }
        },
      ),
    );
  }

  Future<void> _resumeZipJob(
    OperationJob job,
    Uint8List masterKey,
    BlobStore blobStore,
    JobRepository jobRepo,
    String zipPath,
  ) async {
    if (!mounted) return;

    // Find destination folder from previously committed items.
    final committedItems = await jobRepo.findCompletedItems(job.id);

    // If no items were committed before the crash, destFolderId is null,
    // meaning files land in the vault root. This is intentional: we have no
    // other record of where the user intended the files to go.
    final int? destFolderId =
        committedItems.isNotEmpty ? committedItems.first.parentFolderId : null;
    if (committedItems.isEmpty) {
      debugPrint('[ResumeZip] No committed items found; '
          'resume files will land in vault root.');
    }

    final repo = VaultRepository(
      crypto: const FileCryptoService(),
      secureStorage: SecureStorageService.instance,
    );
    final existingFiles = await repo.listFiles(parentId: destFolderId);
    final alreadyCommitted = existingFiles.map((f) => f.originalName).toSet();

    await _resumeZipWithReader(
      job: job,
      masterKey: masterKey,
      blobStore: blobStore,
      jobRepo: jobRepo,
      zipPath: zipPath,
      destFolderId: destFolderId,
      alreadyCommitted: alreadyCommitted,
      repo: repo,
    );
  }

  Future<void> _resumeZipWithReader({
    required OperationJob job,
    required Uint8List masterKey,
    required BlobStore blobStore,
    required JobRepository jobRepo,
    required String zipPath,
    required int? destFolderId,
    required Set<String> alreadyCommitted,
    required VaultRepository repo,
  }) async {
    final reader = ArchiveReader();
    final crypto = DartCryptoEngine();

    await for (final e in reader.entries(zipPath)) {
      if (e is ArchiveEntrySkipped) continue;
      if (e is! ArchiveEntry) continue;

      final baseName = path.basename(e.name);
      if (alreadyCommitted.contains(baseName)) {
        try {
          File(e.tempPath).deleteSync();
        } catch (_) {}
        continue;
      }

      try {
        final blobId = _appGenerateBlobId();
        final partialPath = await blobStore.createPartialPath(blobId);
        final encResult = await crypto.encryptFile(
          sourcePath: e.tempPath,
          destPath: partialPath,
          key: masterKey,
        );
        try {
          File(e.tempPath).deleteSync();
        } catch (_) {}
        await blobStore.commitPartial(blobId);
        await repo.addEncryptedBlobRecord(
          originalName: baseName,
          parentFolderId: destFolderId,
          blobId: blobId,
          ivBase64: encResult.ivBase64,
          byteSize: encResult.byteSize,
          formatVersion: encResult.formatVersion,
        );
      } catch (err) {
        try {
          File(e.tempPath).deleteSync();
        } catch (_) {}
        debugPrint('[ResumeZip] Failed to encrypt entry "$baseName": $err');
      }
    }

    await jobRepo.markJobState(job.id, JobState.completed);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _getHomeScreen()),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Rollback-marker check (6.4) — interrupted password change
  // ---------------------------------------------------------------------------

  Future<void> _checkRollbackMarker() async {
    if (!mounted) return;
    final repo = CredentialRepository();
    final hasMarker = await repo.hasRollbackMarker();
    if (!hasMarker) return;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Password Change Interrupted'),
        content: const Text(
          'A previous password change was not completed. '
          'Your original password is still active. '
          'Tap Continue to keep using your original password, '
          'or change your password again from Settings.',
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await repo.deleteRollbackMarker();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Platform-aware home screen helper
  // ---------------------------------------------------------------------------

  Widget _getHomeScreen() {
    return defaultTargetPlatform == TargetPlatform.android
        ? const MobileHomeScreen()
        : const HomeScreen();
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

class _InterruptedJobsDialog extends StatelessWidget {
  const _InterruptedJobsDialog({
    required this.jobs,
    required this.itemCount,
  });

  final List<OperationJob> jobs;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Interrupted Import Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The app was interrupted during a previous import. '
            '$itemCount file(s) have incomplete data on disk.',
          ),
          const SizedBox(height: 12),
          Text(
            'Resume to continue the import, or Discard to clean up.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _RecoveryChoice.discard),
          child: const Text('Discard'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _RecoveryChoice.resume),
          child: const Text('Resume'),
        ),
      ],
    );
  }
}

class _ResumeProgressDialog extends StatefulWidget {
  const _ResumeProgressDialog({
    required this.runner,
    required this.job,
    required this.masterKey,
    required this.onComplete,
  });

  final JobRunner runner;
  final OperationJob job;
  final Uint8List masterKey;
  final VoidCallback onComplete;

  @override
  State<_ResumeProgressDialog> createState() => _ResumeProgressDialogState();
}

class _ResumeProgressDialogState extends State<_ResumeProgressDialog> {
  int _completed = 0;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runResume();
  }

  Future<void> _runResume() async {
    try {
      await for (final progress
          in widget.runner.run(widget.job, widget.masterKey)) {
        if (!mounted) return;
        setState(() {
          _completed = progress.completedItems;
          _total = progress.totalItems;
        });
      }
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // never allow back-dismiss during resume
      child: AlertDialog(
        title: const Text('Resuming Import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error == null) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_total > 0
                  ? 'Importing $_completed / $_total files…'
                  : 'Resuming…'),
            ] else ...[
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Dismiss'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
