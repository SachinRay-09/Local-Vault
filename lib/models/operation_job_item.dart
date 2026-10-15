import 'package:isar/isar.dart';

part 'operation_job_item.g.dart';

/// Lifecycle state of an individual [OperationJobItem].
enum JobItemState {
  pending,
  running,
  completed,
  failed,
  skipped,
}

@collection
class OperationJobItem {
  Id id = Isar.autoIncrement;

  @Index()
  late int jobId;

  @enumerated
  late JobItemState state;

  late String sourcePath;
  late String blobId;

  String? partialBlobPath;

  late int sourceSizeBytes;

  String? failureReason;
}
