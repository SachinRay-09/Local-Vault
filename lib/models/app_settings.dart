import 'package:isar/isar.dart';

part 'app_settings.g.dart';

@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  /// Optional storage cap.
  int? maxStorageBytes;

  /// Custom temp folder path for Android manga reader integration
  String? customTempFolderPath;
}

