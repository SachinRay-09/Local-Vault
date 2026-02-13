// Stub file - Vault file export/import has been removed
// This file exists only to prevent compilation errors
// ZIP import/export is the recommended method

class EncryptedExportService {
  EncryptedExportService({required dynamic repo, required dynamic openService});
  
  Future<EncryptedExportResult> exportFolderAsEncryptedArchive({
    required dynamic folder,
    required String password,
    required String outputPath,
    Function(String)? onProgress,
  }) async {
    return EncryptedExportResult(
      success: false,
      message: 'Vault file export has been removed. Please use ZIP export instead.',
      filesExported: 0,
      outputPath: '',
    );
  }
}

class EncryptedExportResult {
  final bool success;
  final String message;
  final int filesExported;
  final String outputPath;
  
  EncryptedExportResult({
    required this.success,
    required this.message,
    required this.filesExported,
    required this.outputPath,
  });
}
