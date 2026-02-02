import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_open_service.dart';
import 'vault_repository.dart';

class YomikiruIntegrationService {
  YomikiruIntegrationService({
    required this.repo,
    required this.openService,
  });

  final VaultRepository repo;
  final VaultOpenService openService;

  /// Export a folder to a temporary location and open with Yomikiru
  Future<String> openFolderInYomikiru(VaultFolder folder) async {
    try {
      // Create temporary export directory
      final tempDir = await _createTempExportDir(folder.name);
      
      // Get all files in the folder (including subfolders)
      final allFiles = await _getAllFilesInFolder(folder.id);
      
      if (allFiles.isEmpty) {
        throw Exception('No images found in folder "${folder.name}"');
      }

      // Decrypt and export all images to temp directory
      await _exportFilesToTemp(allFiles, tempDir, folder.id);
      
      // Try to launch Yomikiru with the folder
      await _launchYomikiru(tempDir.path);
      
      return tempDir.path;
    } catch (e) {
      debugPrint('Failed to open folder in Yomikiru: $e');
      rethrow;
    }
  }

  /// Get all image files in a folder recursively
  Future<List<VaultFile>> _getAllFilesInFolder(int folderId) async {
    final List<VaultFile> allFiles = [];
    final foldersToProcess = <int>[folderId];
    
    while (foldersToProcess.isNotEmpty) {
      final currentFolderId = foldersToProcess.removeAt(0);
      
      // Get files in current folder
      final files = await repo.listFiles(parentId: currentFolderId);
      allFiles.addAll(files.where((f) => _isImageFile(f.originalName)));
      
      // Get subfolders
      final subfolders = await repo.listFolders(parentId: currentFolderId);
      foldersToProcess.addAll(subfolders.map((f) => f.id));
    }
    
    // Sort files by name for proper reading order
    allFiles.sort((a, b) => a.originalName.compareTo(b.originalName));
    
    return allFiles;
  }

  /// Create temporary directory for export
  Future<Directory> _createTempExportDir(String folderName) async {
    final tempBaseDir = Directory.systemTemp;
    final exportDir = Directory(
      path.join(tempBaseDir.path, 'local_vault_yomikiru', _sanitizeFolderName(folderName))
    );
    
    // Clean up existing directory
    if (await exportDir.exists()) {
      await exportDir.delete(recursive: true);
    }
    
    await exportDir.create(recursive: true);
    return exportDir;
  }

  /// Export files to temporary directory maintaining folder structure
  Future<void> _exportFilesToTemp(
    List<VaultFile> files, 
    Directory tempDir, 
    int rootFolderId
  ) async {
    for (final file in files) {
      try {
        // Decrypt file
        final decryptedFile = await openService.decryptToCachedTempFile(file);
        
        // Determine relative path
        String relativePath = file.originalName;
        if (file.parentFolderId != null && file.parentFolderId != rootFolderId) {
          final folderPath = await _getFolderPath(file.parentFolderId!, rootFolderId);
          relativePath = path.join(folderPath, file.originalName);
        }
        
        // Create destination file
        final destFile = File(path.join(tempDir.path, relativePath));
        await destFile.parent.create(recursive: true);
        
        // Copy decrypted file
        await decryptedFile.copy(destFile.path);
        
      } catch (e) {
        debugPrint('Failed to export file ${file.originalName}: $e');
      }
    }
  }

  /// Get folder path relative to root folder
  Future<String> _getFolderPath(int folderId, int rootFolderId) async {
    final List<String> pathParts = [];
    int? currentId = folderId;
    
    while (currentId != null && currentId != rootFolderId) {
      final folders = await repo.listFolders(parentId: null);
      final folder = folders.where((f) => f.id == currentId).firstOrNull;
      
      if (folder == null) break;
      
      pathParts.insert(0, folder.name);
      currentId = folder.parentId;
    }
    
    return pathParts.join(Platform.pathSeparator);
  }

  /// Launch Yomikiru with the specified folder
  Future<void> _launchYomikiru(String folderPath) async {
    if (Platform.isWindows) {
      // Try user-specified path first, then common locations
      final possiblePaths = [
        r'D:\Yomikiru.exe', // User's specific path
        r'C:\Program Files\Yomikiru\Yomikiru.exe',
        r'C:\Program Files (x86)\Yomikiru\Yomikiru.exe',
        path.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Yomikiru', 'Yomikiru.exe'),
        path.join(Platform.environment['APPDATA'] ?? '', 'Local', 'Programs', 'Yomikiru', 'Yomikiru.exe'),
      ];
      
      String? yomikiruPath;
      for (final possiblePath in possiblePaths) {
        if (await File(possiblePath).exists()) {
          yomikiruPath = possiblePath;
          break;
        }
      }
      
      if (yomikiruPath != null) {
        // Launch Yomikiru with folder path
        debugPrint('Launching Yomikiru: $yomikiruPath with folder: $folderPath');
        await Process.start(yomikiruPath, [folderPath], mode: ProcessStartMode.detached);
      } else {
        // Fallback: open folder in file explorer
        await Process.start('explorer', [folderPath], mode: ProcessStartMode.detached);
        throw Exception('Yomikiru not found at expected locations. Please install Yomikiru v2.23.1 or update the path in the code.');
      }
    } else {
      // For other platforms, just open the folder
      throw Exception('Yomikiru integration is currently only supported on Windows');
    }
  }

  /// Check if file is an image
  bool _isImageFile(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.apng', '.avif']
        .contains(ext);
  }

  /// Sanitize folder name for file system
  String _sanitizeFolderName(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
  }

  /// Clean up temporary export directories
  static Future<void> cleanupTempExports() async {
    try {
      final tempBaseDir = Directory(path.join(Directory.systemTemp.path, 'local_vault_yomikiru'));
      if (await tempBaseDir.exists()) {
        await tempBaseDir.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('Failed to cleanup temp exports: $e');
    }
  }
}