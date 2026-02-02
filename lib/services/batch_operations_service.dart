import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_repository.dart';

class BatchOperationsService {
  BatchOperationsService({required this.repo});

  final VaultRepository repo;

  Future<void> deleteFiles(List<VaultFile> files) async {
    for (final file in files) {
      await repo.deleteFile(fileId: file.id);
    }
  }

  Future<void> deleteFolders(List<VaultFolder> folders) async {
    for (final folder in folders) {
      await repo.deleteFolderRecursive(folderId: folder.id);
    }
  }

  Future<void> moveFiles(List<VaultFile> files, int? destinationFolderId) async {
    for (final file in files) {
      await repo.moveFile(fileId: file.id, newParentFolderId: destinationFolderId);
    }
  }

  Future<void> moveFolders(List<VaultFolder> folders, int? destinationFolderId) async {
    for (final folder in folders) {
      await repo.moveFolder(folderId: folder.id, newParentId: destinationFolderId);
    }
  }
}