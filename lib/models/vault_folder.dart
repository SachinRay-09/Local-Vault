import 'package:isar/isar.dart';

part 'vault_folder.g.dart';

@collection
class VaultFolder {
  Id id = Isar.autoIncrement;

  late String name;

  /// Null means root.
  @Index()
  int? parentId;

  late DateTime createdAt;
  late DateTime updatedAt;
}

