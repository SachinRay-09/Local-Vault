import 'package:isar/isar.dart';

import '../db/isar_db.dart';
import '../models/operation_job.dart';
import '../models/operation_job_item.dart';

/// Provides CRUD operations for [OperationJob] and [OperationJobItem] records.
class JobRepository {
  JobRepository({Isar? isar}) : _isar = isar ?? IsarDb.instance;

  final Isar _isar;

  /// Inserts [job] and returns its auto-assigned id.
  Future<int> createJob(OperationJob job) async {
    await _isar.writeTxn(() async {
      await _isar.operationJobs.put(job);
    });
    return job.id;
  }

  /// Inserts [item] and returns its auto-assigned id.
  Future<int> createJobItem(OperationJobItem item) async {
    await _isar.writeTxn(() async {
      await _isar.operationJobItems.put(item);
    });
    return item.id;
  }

  /// Updates the [JobState] of the job identified by [id].
  Future<void> markJobState(int id, JobState state) async {
    final job = await _isar.operationJobs.get(id);
    if (job == null) return;
    job.state = state;
    await _isar.writeTxn(() async {
      await _isar.operationJobs.put(job);
    });
  }

  /// Updates the [JobItemState] of the item identified by [id].
  /// Optionally records a [failureReason] when the state is [JobItemState.failed].
  Future<void> markJobItemState(
    int id,
    JobItemState state, {
    String? failureReason,
  }) async {
    final item = await _isar.operationJobItems.get(id);
    if (item == null) return;
    item.state = state;
    if (failureReason != null) {
      item.failureReason = failureReason;
    }
    await _isar.writeTxn(() async {
      await _isar.operationJobItems.put(item);
    });
  }

  /// Returns jobs that were left in [JobState.running] or [JobState.interrupted]
  /// — i.e. jobs that need to be resumed or cleaned up on next launch.
  Future<List<OperationJob>> findInterruptedJobs() async {
    return _isar.operationJobs
        .filter()
        .stateEqualTo(JobState.running)
        .or()
        .stateEqualTo(JobState.interrupted)
        .findAll();
  }

  /// Returns all [OperationJobItem] rows for [jobId] that are still pending.
  Future<List<OperationJobItem>> findPendingItems(int jobId) async {
    return _isar.operationJobItems
        .filter()
        .jobIdEqualTo(jobId)
        .stateEqualTo(JobItemState.pending)
        .findAll();
  }

  /// Returns all [OperationJobItem] rows for [jobId] with state [pending] OR
  /// [running] — used by crash-recovery to find items that were in-flight when
  /// the app was killed.
  Future<List<OperationJobItem>> findPendingOrRunningItems(int jobId) async {
    return _isar.operationJobItems
        .filter()
        .jobIdEqualTo(jobId)
        .stateEqualTo(JobItemState.pending)
        .or()
        .jobIdEqualTo(jobId)
        .stateEqualTo(JobItemState.running)
        .findAll();
  }

  /// Persists the [partialBlobPath] on the item identified by [id] so that
  /// crash-recovery can locate and clean up the partial blob file.
  Future<void> saveItemPartialPath(int id, String partialPath) async {
    final item = await _isar.operationJobItems.get(id);
    if (item == null) return;
    item.partialBlobPath = partialPath;
    await _isar.writeTxn(() async {
      await _isar.operationJobItems.put(item);
    });
  }

  /// Deletes the job identified by [id] and all of its associated items.
  Future<void> deleteJob(int id) async {
    final itemIds = await _isar.operationJobItems
        .filter()
        .jobIdEqualTo(id)
        .idProperty()
        .findAll();

    await _isar.writeTxn(() async {
      await _isar.operationJobItems.deleteAll(itemIds);
      await _isar.operationJobs.delete(id);
    });
  }
}
