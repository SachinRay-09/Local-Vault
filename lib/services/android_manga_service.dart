import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive.dart';
import 'package:device_info_plus/device_info_plus.dart';

import '../models/vault_file.dart';
import '../models/vault_folder.dart';
import 'vault_repository.dart';
import 'vault_open_service.dart';
import 'vault_paths.dart';
import 'settings_service.dart';

/// Android-specific service for manga reading workflow
/// Handles export from PC, import to Android, and integration with external manga readers
/// Enhanced with custom temp folder locations and Mihon priority integration
class AndroidMangaService {
  AndroidMangaService({
    required this.repo,
    required this.openService,
    required this.settingsService,
  });

  final VaultRepository repo;
  final VaultOpenService openService;
  final SettingsService settingsService;

  /// Export a folder for Android transfer (creates encrypted ZIP)
  Future<AndroidExportResult> exportFolderForAndroid(VaultFolder folder) async {
    try {
      // Create temp directory for export
      final tempDir = await _createTempExportDirectory();
      final exportPath = path.join(tempDir.path, '${folder.name}_android_export.vault');

      // Get all files in folder recursively
      final allFiles = await _getAllFilesInFolder(folder.id);
      
      debugPrint('Android Export: Found ${allFiles.length} files in folder "${folder.name}"');

      // Create export metadata
      final exportMetadata = AndroidExportMetadata(
        folderName: folder.name,
        fileCount: allFiles.length,
        exportDate: DateTime.now(),
        version: '1.2.1',
        platform: 'android',
      );

      // Export files with metadata
      await _createAndroidExportFile(
        allFiles,
        folder,
        exportPath,
        exportMetadata,
      );

      return AndroidExportResult(
        success: true,
        exportPath: exportPath,
        metadata: exportMetadata,
        message: 'Successfully exported ${allFiles.length} files for Android',
      );

    } catch (e) {
      debugPrint('Android export error: $e');
      return AndroidExportResult(
        success: false,
        exportPath: '',
        metadata: null,
        message: 'Export failed: $e',
      );
    }
  }

  /// Import Android vault file
  Future<AndroidImportResult> importAndroidVault({
    required String vaultFilePath,
    required String password,
    Function(String)? onProgress,
  }) async {
    try {
      onProgress?.call('Validating vault file...');
      
      // Validate vault file
      final vaultFile = File(vaultFilePath);
      if (!await vaultFile.exists()) {
        throw Exception('Vault file not found');
      }

      onProgress?.call('Reading vault metadata...');
      
      // Read and decrypt vault file
      final importResult = await _importVaultFile(vaultFile, password, onProgress);
      
      return AndroidImportResult(
        success: true,
        foldersCreated: importResult.foldersCreated,
        filesImported: importResult.filesImported,
        errors: importResult.errors,
        message: 'Successfully imported ${importResult.filesImported} files',
      );

    } catch (e) {
      debugPrint('Android import error: $e');
      return AndroidImportResult(
        success: false,
        foldersCreated: 0,
        filesImported: 0,
        errors: [e.toString()],
        message: 'Import failed: $e',
      );
    }
  }

  /// Open folder in external manga reader with enhanced Mihon integration
  Future<AndroidMangaReaderResult> openInMangaReader(VaultFolder folder) async {
    try {
      // Check storage permissions
      final hasPermission = await _checkStoragePermissions();
      if (!hasPermission) {
        return AndroidMangaReaderResult(
          success: false,
          tempFolderPath: '',
          message: 'Storage permission required for manga reader access',
        );
      }

      // Detect Mihon first
      final mihonDetection = await detectMihon();
      
      // Get custom temp folder location
      final tempBasePath = await getCurrentTempFolderLocation();
      
      // Create temp folder for manga reader in custom location
      final tempDir = await _createMangaReaderTempFolder(folder.name, tempBasePath);
      
      // Export all images to temp folder
      final exportResult = await _exportFolderToTemp(folder, tempDir);
      
      if (!exportResult.success) {
        return AndroidMangaReaderResult(
          success: false,
          tempFolderPath: tempDir.path,
          message: 'Failed to export images: ${exportResult.message}',
          mihonDetected: mihonDetection.isInstalled,
          mihonAppName: mihonDetection.appName,
        );
      }

      // Try to launch manga reader with Mihon priority
      final readerResult = await _launchMangaReaderWithMihonPriority(tempDir.path, mihonDetection);
      
      return AndroidMangaReaderResult(
        success: true,
        tempFolderPath: tempDir.path,
        message: readerResult.success 
            ? 'Opened in ${readerResult.appName ?? 'manga reader'} successfully'
            : 'Images exported to: ${tempDir.path}\n${mihonDetection.isInstalled ? 'Open Mihon and navigate to this folder' : 'Install Mihon for best experience'}',
        readerLaunched: readerResult.success,
        mihonDetected: mihonDetection.isInstalled,
        mihonAppName: mihonDetection.appName,
        tempFolderLocation: tempBasePath,
      );

    } catch (e) {
      debugPrint('Manga reader error: $e');
      return AndroidMangaReaderResult(
        success: false,
        tempFolderPath: '',
        message: 'Failed to open in manga reader: $e',
      );
    }
  }

  /// Clean up temp folder after reading
  Future<bool> cleanupMangaReaderTemp(String tempFolderPath) async {
    try {
      final tempDir = Directory(tempFolderPath);
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        debugPrint('Cleaned up manga reader temp folder: $tempFolderPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Cleanup error: $e');
      return false;
    }
  }

  /// Share vault file for transfer to other devices
  Future<void> shareVaultFile(String vaultFilePath) async {
    try {
      final file = XFile(vaultFilePath);
      await Share.shareXFiles(
        [file],
        text: 'Local Vault encrypted folder - use Local Vault app to import',
        subject: 'Encrypted Manga Collection',
      );
    } catch (e) {
      debugPrint('Share error: $e');
      rethrow;
    }
  }

  /// Get recommended manga reader apps (including Mihon)
  List<MangaReaderApp> getRecommendedMangaReaders() {
    return [
      MangaReaderApp(
        name: 'Mihon',
        packageName: 'eu.kanade.tachiyomi',
        description: 'Popular open-source manga reader (Tachiyomi fork)',
        supportsLocalFiles: true,
        isPriority: true, // User's preferred app
      ),
      MangaReaderApp(
        name: 'Tachiyomi',
        packageName: 'eu.kanade.tachiyomi.stable',
        description: 'Original Tachiyomi manga reader',
        supportsLocalFiles: true,
      ),
      MangaReaderApp(
        name: 'Perfect Viewer',
        packageName: 'com.rookiestudio.perfectviewer',
        description: 'Excellent for local manga collections',
        supportsLocalFiles: true,
      ),
      MangaReaderApp(
        name: 'ComicScreen',
        packageName: 'com.viewer.comicscreen',
        description: 'Simple and fast comic/manga viewer',
        supportsLocalFiles: true,
      ),
      MangaReaderApp(
        name: 'CDisplayEx',
        packageName: 'com.progdigy.cdisplay',
        description: 'Feature-rich comic book reader',
        supportsLocalFiles: true,
      ),
    ];
  }

  /// Get current temp folder location setting
  Future<String> getCurrentTempFolderLocation() async {
    try {
      final settings = await settingsService.getSettings();
      if (settings.customTempFolderPath != null && settings.customTempFolderPath!.isNotEmpty) {
        return settings.customTempFolderPath!;
      }
      
      // Default to Manga folder in internal storage root (alongside DCIM, Download, Documents)
      // This is the standard Android internal storage structure: /storage/emulated/0/
      const mangaPath = '/storage/emulated/0/Manga/LocalVault';
      return mangaPath;
    } catch (e) {
      debugPrint('Error getting temp folder location: $e');
      // Final fallback to Manga folder
      return '/storage/emulated/0/Manga/LocalVault';
    }
  }

  /// Set custom temp folder location
  Future<bool> setCustomTempFolderLocation(String folderPath) async {
    try {
      // Validate the folder path
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Test write permissions
      final testFile = File(path.join(folderPath, 'test_write.tmp'));
      await testFile.writeAsString('test');
      await testFile.delete();
      
      // Save to settings
      final settings = await settingsService.getSettings();
      settings.customTempFolderPath = folderPath;
      await settingsService.saveSettings(settings);
      
      debugPrint('Custom temp folder set to: $folderPath');
      return true;
    } catch (e) {
      debugPrint('Error setting custom temp folder: $e');
      return false;
    }
  }

  /// Get available temp folder locations for user selection
  Future<List<TempFolderOption>> getAvailableTempFolderLocations() async {
    final options = <TempFolderOption>[];
    
    try {
      // Manga folder in internal storage root (RECOMMENDED - alongside DCIM, Download, Documents)
      const mangaPath = '/storage/emulated/0/Manga/LocalVault';
      options.add(TempFolderOption(
        name: 'Manga/LocalVault',
        path: mangaPath,
        description: 'Recommended: In Internal Storage alongside DCIM, Download, Documents',
        isRecommended: true,
      ));
      
      // Public Downloads folder (alternative)
      const downloadsPath = '/storage/emulated/0/Download/LocalVault';
      options.add(TempFolderOption(
        name: 'Download/LocalVault',
        path: downloadsPath,
        description: 'Alternative: In Downloads folder',
        isRecommended: false,
      ));
      
      // Mihon-compatible folder (if user prefers)
      const mihonPath = '/storage/emulated/0/Mihon/LocalVault';
      options.add(TempFolderOption(
        name: 'Mihon/LocalVault',
        path: mihonPath,
        description: 'Mihon-specific folder (if Mihon is installed)',
        isRecommended: false,
      ));
      
      // Root storage location
      const rootPath = '/storage/emulated/0/LocalVault';
      options.add(TempFolderOption(
        name: 'LocalVault (Root)',
        path: rootPath,
        description: 'Root storage location',
        isRecommended: false,
      ));
      
    } catch (e) {
      debugPrint('Error getting temp folder options: $e');
    }
    
    return options;
  }

  /// Check if Mihon is installed and get its details
  Future<MihonDetectionResult> detectMihon() async {
    try {
      // Check for Mihon (Tachiyomi fork)
      final mihonUri = Uri.parse('package:eu.kanade.tachiyomi');
      final isMihonInstalled = await canLaunchUrl(mihonUri);
      
      if (isMihonInstalled) {
        return MihonDetectionResult(
          isInstalled: true,
          appName: 'Mihon',
          packageName: 'eu.kanade.tachiyomi',
          description: 'Mihon manga reader detected - optimized integration available',
          supportsLocalFolders: true,
        );
      }
      
      // Check for original Tachiyomi
      final tachiyomiUri = Uri.parse('package:eu.kanade.tachiyomi.stable');
      final isTachiyomiInstalled = await canLaunchUrl(tachiyomiUri);
      
      if (isTachiyomiInstalled) {
        return MihonDetectionResult(
          isInstalled: true,
          appName: 'Tachiyomi',
          packageName: 'eu.kanade.tachiyomi.stable',
          description: 'Tachiyomi manga reader detected',
          supportsLocalFolders: true,
        );
      }
      
      return MihonDetectionResult(
        isInstalled: false,
        appName: null,
        packageName: null,
        description: 'Mihon/Tachiyomi not found. Install Mihon for best experience.',
        supportsLocalFolders: false,
      );
      
    } catch (e) {
      debugPrint('Error detecting Mihon: $e');
      return MihonDetectionResult(
        isInstalled: false,
        appName: null,
        packageName: null,
        description: 'Error detecting manga readers: $e',
        supportsLocalFolders: false,
      );
    }
  }

  /// Launch Mihon specifically with the temp folder
  Future<AndroidMangaReaderLaunchResult> launchMihon(String folderPath) async {
    try {
      // Try to launch Mihon directly
      final mihonUri = Uri.parse('eu.kanade.tachiyomi://local?path=${Uri.encodeComponent(folderPath)}');
      if (await canLaunchUrl(mihonUri)) {
        await launchUrl(mihonUri, mode: LaunchMode.externalApplication);
        return AndroidMangaReaderLaunchResult(success: true, appName: 'Mihon');
      }

      // Fallback to package launch
      final packageUri = Uri.parse('package:eu.kanade.tachiyomi');
      if (await canLaunchUrl(packageUri)) {
        await launchUrl(packageUri);
        return AndroidMangaReaderLaunchResult(success: true, appName: 'Mihon');
      }

      return AndroidMangaReaderLaunchResult(success: false);
    } catch (e) {
      debugPrint('Error launching Mihon: $e');
      return AndroidMangaReaderLaunchResult(success: false);
    }
  }

  // Private helper methods

  Future<Directory> _createTempExportDirectory() async {
    final tempDir = Directory.systemTemp;
    final exportDir = Directory(path.join(tempDir.path, 'local_vault_android_export'));
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  Future<List<VaultFile>> _getAllFilesInFolder(int folderId) async {
    // Get all files recursively from folder and subfolders
    final files = <VaultFile>[];
    
    // Get direct files
    final directFiles = await repo.listFiles(parentId: folderId);
    files.addAll(directFiles);
    
    // Get files from subfolders recursively
    final subfolders = await repo.listFolders(parentId: folderId);
    for (final subfolder in subfolders) {
      final subfolderFiles = await _getAllFilesInFolder(subfolder.id);
      files.addAll(subfolderFiles);
    }
    
    return files;
  }

  Future<void> _createAndroidExportFile(
    List<VaultFile> files,
    VaultFolder folder,
    String exportPath,
    AndroidExportMetadata metadata,
  ) async {
    try {
      // Create export archive with encrypted files
      final archive = Archive();
      
      // Add metadata file
      final metadataJson = {
        'folderName': metadata.folderName,
        'fileCount': metadata.fileCount,
        'exportDate': metadata.exportDate.toIso8601String(),
        'version': metadata.version,
        'platform': metadata.platform,
      };
      
      final metadataFile = ArchiveFile(
        'vault_metadata.json',
        metadataJson.toString().codeUnits.length,
        metadataJson.toString().codeUnits,
      );
      archive.addFile(metadataFile);
      
      // Add encrypted files to archive
      for (final file in files) {
        try {
          // Get full path to encrypted blob file
          final encryptedFilePath = await _getEncryptedFilePath(file);
          final encryptedData = await File(encryptedFilePath).readAsBytes();
          
          // Create archive entry with original name and encrypted data
          final archiveFile = ArchiveFile(
            file.originalName,
            encryptedData.length,
            encryptedData,
          );
          archive.addFile(archiveFile);
          
          debugPrint('Added ${file.originalName} to Android export (${encryptedData.length} bytes)');
        } catch (e) {
          debugPrint('Failed to add file ${file.originalName} to export: $e');
        }
      }
      
      // Create ZIP file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      
      if (zipData != null) {
        final exportFile = File(exportPath);
        await exportFile.writeAsBytes(zipData);
        debugPrint('Created Android export file: $exportPath (${zipData.length} bytes)');
      } else {
        throw Exception('Failed to create ZIP archive');
      }
      
    } catch (e) {
      debugPrint('Export file creation error: $e');
      rethrow;
    }
  }

  Future<AndroidImportFileResult> _importVaultFile(
    File vaultFile,
    String password,
    Function(String)? onProgress,
  ) async {
    try {
      onProgress?.call('Reading vault file...');
      
      // Read and decode ZIP archive
      final zipData = await vaultFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipData);
      
      onProgress?.call('Validating metadata...');
      
      // Find and validate metadata
      final metadataFile = archive.files.firstWhere(
        (file) => file.name == 'vault_metadata.json',
        orElse: () => throw Exception('Invalid vault file: missing metadata'),
      );
      
      final metadataContent = String.fromCharCodes(metadataFile.content as List<int>);
      debugPrint('Vault metadata: $metadataContent');
      
      onProgress?.call('Creating folder structure...');
      
      // Create root folder for imported content
      final rootFolder = await repo.createFolder(
        name: 'Imported_${DateTime.now().millisecondsSinceEpoch}',
        parentId: null,
      );
      
      int filesImported = 0;
      final errors = <String>[];
      
      onProgress?.call('Importing files...');
      
      // Import each file from archive
      for (final archiveFile in archive.files) {
        if (archiveFile.name == 'vault_metadata.json') continue;
        if (archiveFile.isFile) {
          try {
            // The files in the archive are already encrypted
            // We need to save them as encrypted files in our vault
            final encryptedData = archiveFile.content as List<int>;
            
            // Create vault file entry using addMedia method
            await repo.addMedia(
              originalName: archiveFile.name,
              parentFolderId: rootFolder.id,
              sourcePath: null,
              bytes: Uint8List.fromList(encryptedData),
            );
            
            filesImported++;
            onProgress?.call('Imported ${archiveFile.name} ($filesImported files)');
            
          } catch (e) {
            final error = 'Failed to import ${archiveFile.name}: $e';
            errors.add(error);
            debugPrint(error);
          }
        }
      }
      
      onProgress?.call('Import completed');
      
      return AndroidImportFileResult(
        foldersCreated: 1,
        filesImported: filesImported,
        errors: errors,
      );
      
    } catch (e) {
      debugPrint('Vault file import error: $e');
      rethrow;
    }
  }

  /// Request all necessary storage permissions for the app
  /// This should be called on app startup or when accessing storage features
  Future<StoragePermissionResult> requestAllStoragePermissions() async {
    try {
      if (!Platform.isAndroid) {
        return StoragePermissionResult(
          granted: true,
          message: 'Storage permissions not required on this platform',
        );
      }

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;
      
      debugPrint('Requesting storage permissions for Android API $sdkInt');

      if (sdkInt >= 33) {
        // Android 13+ (API 33+) - Request granular media permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.manageExternalStorage,
        ];
        
        final statuses = await permissions.request();
        final allGranted = statuses.values.every((status) => status.isGranted);
        
        if (!allGranted) {
          final deniedPermissions = statuses.entries
              .where((entry) => !entry.value.isGranted)
              .map((entry) => entry.key.toString())
              .toList();
          
          return StoragePermissionResult(
            granted: false,
            message: 'Some permissions denied: ${deniedPermissions.join(', ')}',
            needsSettings: statuses.values.any((status) => status.isPermanentlyDenied),
          );
        }
        
        return StoragePermissionResult(
          granted: true,
          message: 'All storage permissions granted for Android 13+',
        );
        
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32) - Request MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.request();
        
        if (status.isGranted) {
          return StoragePermissionResult(
            granted: true,
            message: 'Full storage access granted for Android 11+',
          );
        } else {
          return StoragePermissionResult(
            granted: false,
            message: 'MANAGE_EXTERNAL_STORAGE permission required for full file access',
            needsSettings: status.isPermanentlyDenied,
          );
        }
        
      } else if (sdkInt >= 23) {
        // Android 6-10 (API 23-29) - Request legacy storage permissions
        final permissions = [
          Permission.storage,
        ];
        
        final statuses = await permissions.request();
        final allGranted = statuses.values.every((status) => status.isGranted);
        
        if (allGranted) {
          return StoragePermissionResult(
            granted: true,
            message: 'Storage permissions granted for Android 6-10',
          );
        } else {
          return StoragePermissionResult(
            granted: false,
            message: 'Storage permission required',
            needsSettings: statuses.values.any((status) => status.isPermanentlyDenied),
          );
        }
        
      } else {
        // Android < 6 - No runtime permissions needed
        return StoragePermissionResult(
          granted: true,
          message: 'No runtime permissions required for Android < 6',
        );
      }
      
    } catch (e) {
      debugPrint('Error requesting storage permissions: $e');
      return StoragePermissionResult(
        granted: false,
        message: 'Error requesting permissions: $e',
      );
    }
  }

  /// Check if all necessary storage permissions are granted
  Future<bool> hasAllStoragePermissions() async {
    try {
      if (!Platform.isAndroid) return true;

      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = deviceInfo.version.sdkInt;

      if (sdkInt >= 33) {
        // Android 13+ - Check granular media permissions
        final permissions = [
          Permission.photos,
          Permission.videos,
          Permission.audio,
          Permission.manageExternalStorage,
        ];
        
        for (final permission in permissions) {
          final status = await permission.status;
          if (!status.isGranted) return false;
        }
        return true;
        
      } else if (sdkInt >= 30) {
        // Android 11+ - Check MANAGE_EXTERNAL_STORAGE
        final status = await Permission.manageExternalStorage.status;
        return status.isGranted;
        
      } else if (sdkInt >= 23) {
        // Android 6-10 - Check legacy storage permission
        final status = await Permission.storage.status;
        return status.isGranted;
        
      } else {
        // Android < 6 - No runtime permissions needed
        return true;
      }
      
    } catch (e) {
      debugPrint('Error checking storage permissions: $e');
      return false;
    }
  }
  /// Check storage permissions (legacy method - use hasAllStoragePermissions instead)
  Future<bool> _checkStoragePermissions() async {
    return await hasAllStoragePermissions();
  }

  Future<Directory> _createMangaReaderTempFolder(String folderName, [String? customBasePath]) async {
    final basePath = customBasePath ?? await getCurrentTempFolderLocation();
    final mangaDir = Directory(path.join(basePath, 'manga_temp', folderName));
    
    if (await mangaDir.exists()) {
      await mangaDir.delete(recursive: true);
    }
    await mangaDir.create(recursive: true);
    
    debugPrint('Created manga temp folder: ${mangaDir.path}');
    return mangaDir;
  }

  Future<AndroidMangaReaderLaunchResult> _launchMangaReaderWithMihonPriority(
    String folderPath, 
    MihonDetectionResult mihonDetection
  ) async {
    try {
      // First priority: Launch Mihon if detected
      if (mihonDetection.isInstalled && mihonDetection.packageName != null) {
        final mihonResult = await _launchSpecificMangaReader(
          folderPath, 
          mihonDetection.packageName!, 
          mihonDetection.appName!
        );
        if (mihonResult.success) {
          return mihonResult;
        }
      }

      // Second priority: Try other manga readers
      final readers = getRecommendedMangaReaders();
      for (final reader in readers) {
        if (reader.packageName == mihonDetection.packageName) continue; // Skip already tried
        
        try {
          final result = await _launchSpecificMangaReader(folderPath, reader.packageName, reader.name);
          if (result.success) {
            return result;
          }
        } catch (e) {
          debugPrint('Failed to launch ${reader.name}: $e');
        }
      }

      // Third priority: Try to open folder with system file manager
      final uri = Uri.parse('file://$folderPath');
      final canLaunch = await canLaunchUrl(uri);
      
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return AndroidMangaReaderLaunchResult(success: true, appName: 'File Manager');
      }

      return AndroidMangaReaderLaunchResult(success: false);
    } catch (e) {
      debugPrint('Manga reader launch error: $e');
      return AndroidMangaReaderLaunchResult(success: false);
    }
  }

  Future<AndroidMangaReaderLaunchResult> _launchSpecificMangaReader(
    String folderPath, 
    String packageName, 
    String appName
  ) async {
    try {
      // Try to launch with folder path (for apps that support it)
      final appUri = Uri.parse('$packageName://local?path=${Uri.encodeComponent(folderPath)}');
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return AndroidMangaReaderLaunchResult(success: true, appName: appName);
      }

      // Fallback to package launch
      final packageUri = Uri.parse('package:$packageName');
      if (await canLaunchUrl(packageUri)) {
        await launchUrl(packageUri);
        return AndroidMangaReaderLaunchResult(success: true, appName: appName);
      }

      return AndroidMangaReaderLaunchResult(success: false);
    } catch (e) {
      debugPrint('Error launching $appName: $e');
      return AndroidMangaReaderLaunchResult(success: false);
    }
  }

  Future<AndroidExportTempResult> _exportFolderToTemp(VaultFolder folder, Directory tempDir) async {
    try {
      // Get all files in folder
      final files = await _getAllFilesInFolder(folder.id);
      int exported = 0;

      for (final file in files) {
        try {
          // Decrypt file to temp location
          final tempFilePath = path.join(tempDir.path, file.originalName);
          await openService.decryptToSpecificPath(file, tempFilePath);
          exported++;
        } catch (e) {
          debugPrint('Failed to export file ${file.originalName}: $e');
        }
      }

      return AndroidExportTempResult(
        success: true,
        filesExported: exported,
        message: 'Exported $exported files',
      );
    } catch (e) {
      return AndroidExportTempResult(
        success: false,
        filesExported: 0,
        message: 'Export failed: $e',
      );
    }
  }

  /// Get the full path to the encrypted blob file
  Future<String> _getEncryptedFilePath(VaultFile file) async {
    final blobsDir = await VaultPaths.ensureVaultBlobsDir();
    return '${blobsDir.path}${Platform.pathSeparator}${file.storedBlobName}';
  }
}

// Data classes for Android manga service

class AndroidExportResult {
  final bool success;
  final String exportPath;
  final AndroidExportMetadata? metadata;
  final String message;

  AndroidExportResult({
    required this.success,
    required this.exportPath,
    required this.metadata,
    required this.message,
  });
}

class AndroidExportMetadata {
  final String folderName;
  final int fileCount;
  final DateTime exportDate;
  final String version;
  final String platform;

  AndroidExportMetadata({
    required this.folderName,
    required this.fileCount,
    required this.exportDate,
    required this.version,
    required this.platform,
  });
}

class AndroidImportResult {
  final bool success;
  final int foldersCreated;
  final int filesImported;
  final List<String> errors;
  final String message;

  AndroidImportResult({
    required this.success,
    required this.foldersCreated,
    required this.filesImported,
    required this.errors,
    required this.message,
  });
}

class AndroidImportFileResult {
  final int foldersCreated;
  final int filesImported;
  final List<String> errors;

  AndroidImportFileResult({
    required this.foldersCreated,
    required this.filesImported,
    required this.errors,
  });
}

class AndroidMangaReaderResult {
  final bool success;
  final String tempFolderPath;
  final String message;
  final bool readerLaunched;
  final bool mihonDetected;
  final String? mihonAppName;
  final String? tempFolderLocation;

  AndroidMangaReaderResult({
    required this.success,
    required this.tempFolderPath,
    required this.message,
    this.readerLaunched = false,
    this.mihonDetected = false,
    this.mihonAppName,
    this.tempFolderLocation,
  });
}

class AndroidExportTempResult {
  final bool success;
  final int filesExported;
  final String message;

  AndroidExportTempResult({
    required this.success,
    required this.filesExported,
    required this.message,
  });
}

class AndroidMangaReaderLaunchResult {
  final bool success;
  final String? appName;

  AndroidMangaReaderLaunchResult({
    required this.success,
    this.appName,
  });
}

class MangaReaderApp {
  final String name;
  final String packageName;
  final String description;
  final bool supportsLocalFiles;
  final bool isPriority;

  MangaReaderApp({
    required this.name,
    required this.packageName,
    required this.description,
    required this.supportsLocalFiles,
    this.isPriority = false,
  });
}

class TempFolderOption {
  final String name;
  final String path;
  final String description;
  final bool isRecommended;

  TempFolderOption({
    required this.name,
    required this.path,
    required this.description,
    required this.isRecommended,
  });
}

class MihonDetectionResult {
  final bool isInstalled;
  final String? appName;
  final String? packageName;
  final String description;
  final bool supportsLocalFolders;

  MihonDetectionResult({
    required this.isInstalled,
    required this.appName,
    required this.packageName,
    required this.description,
    required this.supportsLocalFolders,
  });
}

class StoragePermissionResult {
  final bool granted;
  final String message;
  final bool needsSettings;

  StoragePermissionResult({
    required this.granted,
    required this.message,
    this.needsSettings = false,
  });
}