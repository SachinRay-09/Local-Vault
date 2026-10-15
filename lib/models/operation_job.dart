import 'package:isar/isar.dart';

part 'operation_job.g.dart';

/// Type of background operation.
enum JobType {
  import,
  export,
  decryptForViewer,
  migrateEncryption,
}

/// Lifecycle state of an [OperationJob].
enum JobState {
  queued,
  running,
  pausing,
  paused,
  cancelling,
  cancelled,
  completed,
  failed,
  interrupted,
}

@collection
class OperationJob {
  Id id = Isar.autoIncrement;

  @enumerated
  late JobType type;

  @enumerated
  late JobState state;

  late DateTime createdAt;
  DateTime? startedAt;
  DateTime? completedAt;

  late int totalItems;
  late int completedItems;
  late int totalBytes;
  late int processedBytes;

  String? currentItemName;
  String? sourceDescriptor;
  String? destinationDescriptor;
  String? failureCode;

  int retryCount = 0;

  String? resumeData;
}
