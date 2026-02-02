import 'package:isar/isar.dart';

part 'file_tag.g.dart';

@collection
class FileTag {
  Id id = Isar.autoIncrement;

  late String name;
  late String color; // Hex color code
  late DateTime createdAt;
}

@collection
class FileTagAssignment {
  Id id = Isar.autoIncrement;

  @Index()
  late int fileId;
  
  @Index()
  late int tagId;
  
  late DateTime assignedAt;
}