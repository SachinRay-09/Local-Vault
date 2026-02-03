import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_open_service.dart';
import 'vault_repository.dart';

class YomikiruNotFoundException implements Exception {
  final String tempFolderPath;
  YomikiruNotFoundException(this.tempFolderPath);
  
  @override
  String toString() => 'Yomikiru not found. Images exported to: $tempFolderPath';
}

class YomikiruLaunchResult {
  final bool success;
  final String tempFolderPath;
  final Process? process;
  final String? error;
  
  YomikiruLaunchResult({
    required this.success,
    required this.tempFolderPath,
    this.process,
    this.error,
  });
}

class YomikiruIntegrationService {
  YomikiruIntegrationService({
    required this.repo,
    required this.openService,
  });

  final VaultRepository repo;
  final VaultOpenService openService;

  /// Export a folder to a temporary location and open with Yomikiru
  Future<YomikiruLaunchResult> openFolderInYomikiru(VaultFolder folder) async {
    try {
      debugPrint('Starting Yomikiru export for folder: ${folder.name}');
      
      // Create temporary export directory
      final tempDir = await _createTempExportDir(folder.name);
      debugPrint('Created temp directory: ${tempDir.path}');
      
      // Get all files in the folder (including subfolders)
      final allFiles = await _getAllFilesInFolder(folder.id);
      debugPrint('Found ${allFiles.length} image files');
      
      if (allFiles.isEmpty) {
        throw Exception('No images found in folder "${folder.name}"');
      }

      // Decrypt and export all images to temp directory
      await _exportFilesToTemp(allFiles, tempDir, folder.id);
      
      // Try to launch Yomikiru with the folder
      final launchResult = await _launchYomikiru(tempDir.path);
      
      // Always return success with temp path - user will confirm cleanup manually
      return YomikiruLaunchResult(
        success: launchResult['success'] == true,
        tempFolderPath: tempDir.path,
        process: null, // Don't track process since it's detached
        error: launchResult['success'] == true ? null : launchResult['error'] as String?,
      );
    } catch (e) {
      debugPrint('Failed to open folder in Yomikiru: $e');
      rethrow;
    }
  }

  /// Clean up temporary folder
  Future<void> _cleanupTempFolder(String tempFolderPath) async {
    try {
      final tempDir = Directory(tempFolderPath);
      if (await tempDir.exists()) {
        debugPrint('Cleaning up temp folder: $tempFolderPath');
        await tempDir.delete(recursive: true);
        debugPrint('Temp folder cleaned up successfully');
      } else {
        debugPrint('Temp folder already cleaned up: $tempFolderPath');
      }
    } catch (e) {
      debugPrint('Failed to cleanup temp folder $tempFolderPath: $e');
    }
  }

  /// Clean up specific temp folder (for manual cleanup)
  Future<void> cleanupTempFolder(String tempFolderPath) async {
    await _cleanupTempFolder(tempFolderPath);
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
    debugPrint('Exporting ${files.length} files to ${tempDir.path}');
    
    for (final file in files) {
      try {
        // Decrypt file
        final decryptedFile = await openService.decryptToCachedTempFile(file);
        
        // Determine relative path
        String relativePath = file.originalName;
        if (file.parentFolderId != null && file.parentFolderId != rootFolderId) {
          final folderPath = await _getFolderPath(file.parentFolderId!, rootFolderId);
          if (folderPath.isNotEmpty) {
            relativePath = path.join(folderPath, file.originalName);
          }
        }
        
        // Create destination file
        final destFile = File(path.join(tempDir.path, relativePath));
        await destFile.parent.create(recursive: true);
        
        // Copy decrypted file
        await decryptedFile.copy(destFile.path);
        
        debugPrint('Exported: $relativePath');
        
      } catch (e) {
        debugPrint('Failed to export file ${file.originalName}: $e');
        // Continue with other files even if one fails
      }
    }
    
    debugPrint('Export completed to: ${tempDir.path}');
  }

  /// Get folder path relative to root folder
  Future<String> _getFolderPath(int folderId, int rootFolderId) async {
    final List<String> pathParts = [];
    int? currentId = folderId;
    
    while (currentId != null && currentId != rootFolderId) {
      // Get all folders to find the one with the current ID
      final allFolders = await repo.listFolders(parentId: null);
      final folder = allFolders.where((f) => f.id == currentId).firstOrNull;
      
      if (folder == null) {
        // Try to find in subfolders by getting the folder directly
        try {
          final folders = await repo.listFolders(parentId: currentId);
          if (folders.isEmpty) break;
        } catch (e) {
          break;
        }
        break;
      }
      
      pathParts.insert(0, _sanitizeFolderName(folder.name));
      currentId = folder.parentId;
    }
    
    return pathParts.join(Platform.pathSeparator);
  }

  /// Launch Yomikiru with the specified folder and return process info
  Future<Map<String, dynamic>> _launchYomikiru(String folderPath) async {
    if (Platform.isWindows) {
      // Try user-specified path first, then common locations
      final possiblePaths = [
        r'C:\Users\raysa\AppData\Local\yomikiru\Yomikiru.exe', // User's specific path
        r'D:\Yomikiru.exe', // Fallback to previous path
        r'C:\Program Files\Yomikiru\Yomikiru.exe',
        r'C:\Program Files (x86)\Yomikiru\Yomikiru.exe',
        path.join(Platform.environment['LOCALAPPDATA'] ?? '', 'Programs', 'Yomikiru', 'Yomikiru.exe'),
        path.join(Platform.environment['APPDATA'] ?? '', 'Local', 'Programs', 'Yomikiru', 'Yomikiru.exe'),
      ];
      
      String? yomikiruPath;
      for (final possiblePath in possiblePaths) {
        if (await File(possiblePath).exists()) {
          yomikiruPath = possiblePath;
          debugPrint('Found Yomikiru at: $yomikiruPath');
          break;
        }
      }
      
      if (yomikiruPath != null) {
        try {
          // Launch Yomikiru with folder path as argument
          debugPrint('Launching Yomikiru: $yomikiruPath with folder: $folderPath');
          
          // Use shell command to launch Yomikiru without tracking the process
          await Process.run(
            'cmd',
            ['/c', 'start', '""', yomikiruPath, folderPath],
            runInShell: true,
          );
          
          // Give the process a moment to start
          await Future.delayed(const Duration(milliseconds: 1000));
          
          return {
            'success': true,
            'path': yomikiruPath,
          };
        } catch (e) {
          debugPrint('Failed to launch Yomikiru: $e');
          return {'success': false, 'error': e.toString()};
        }
      } else {
        debugPrint('Yomikiru not found at any expected location');
        return {'success': false, 'error': 'Yomikiru not found at expected locations'};
      }
    } else {
      // For other platforms, just return false
      debugPrint('Yomikiru integration is currently only supported on Windows');
      return {'success': false, 'error': 'Platform not supported'};
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
        debugPrint('Cleaning up all temp exports in: ${tempBaseDir.path}');
        await tempBaseDir.delete(recursive: true);
        debugPrint('All temp exports cleaned up successfully');
      }
    } catch (e) {
      debugPrint('Failed to cleanup temp exports: $e');
    }
  }

  /// Get list of current temp export folders
  static Future<List<String>> getCurrentTempFolders() async {
    try {
      final tempBaseDir = Directory(path.join(Directory.systemTemp.path, 'local_vault_yomikiru'));
      if (await tempBaseDir.exists()) {
        final folders = <String>[];
        await for (final entity in tempBaseDir.list()) {
          if (entity is Directory) {
            folders.add(entity.path);
          }
        }
        return folders;
      }
    } catch (e) {
      debugPrint('Failed to list temp folders: $e');
    }
    return [];
  }
}