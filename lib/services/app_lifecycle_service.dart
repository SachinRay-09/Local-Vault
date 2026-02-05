import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'vault_paths.dart';

/// Service to handle app lifecycle events and cleanup temporary files for security
class AppLifecycleService {
  static const Duration _cleanupDelay = Duration(seconds: 10); // Longer delay to avoid interfering with usage
  bool _cleanupScheduled = false;
  bool _appIsClosing = false; // Track if app is actually closing
  
  /// Initialize the lifecycle service (lightweight)
  void initialize() {
    // Minimal initialization - no heavy operations
    debugPrint('AppLifecycleService initialized');
  }
  
  /// Handle app lifecycle state changes (smart cleanup strategy)
  void handleLifecycleChange(AppLifecycleState state) {
    // Only log in debug mode to avoid performance impact
    if (kDebugMode) {
      debugPrint('App lifecycle: $state');
    }
    
    switch (state) {
      case AppLifecycleState.detached:
        // App is actually terminating - mark as closing and cleanup
        _appIsClosing = true;
        _performImmediateCleanup();
        break;
        
      case AppLifecycleState.paused:
        // App backgrounded - only schedule cleanup after longer delay for security
        // Don't cleanup immediately as user might return quickly
        if (!_cleanupScheduled) {
          _scheduleSecurityCleanup();
        }
        break;
        
      case AppLifecycleState.resumed:
        // App resumed - cancel any pending cleanup since user is back
        _cancelScheduledCleanup();
        _appIsClosing = false; // Reset closing flag
        break;
        
      case AppLifecycleState.inactive:
        // App inactive (e.g., phone call) - don't cleanup, user will likely return
        break;
        
      case AppLifecycleState.hidden:
        // App hidden - schedule cleanup only after delay for security
        if (!_cleanupScheduled) {
          _scheduleSecurityCleanup();
        }
        break;
    }
  }
  
  /// Perform immediate comprehensive cleanup when app is terminating
  void _performImmediateCleanup() {
    if (kDebugMode) {
      debugPrint('Immediate comprehensive cleanup on app termination');
    }
    
    // Perform comprehensive cleanup synchronously since app is terminating
    try {
      _performImmediateComprehensiveCleanup();
    } catch (e) {
      // Silently fail to avoid blocking app termination
      if (kDebugMode) {
        debugPrint('Immediate cleanup error: $e');
      }
    }
  }
  
  /// Schedule security cleanup (only when app is truly backgrounded for a while)
  void _scheduleSecurityCleanup() {
    _cleanupScheduled = true;
    
    if (kDebugMode) {
      debugPrint('Scheduling security cleanup after ${_cleanupDelay.inSeconds} seconds');
    }
    
    // Use longer delay to avoid interfering with normal app usage
    Future.delayed(_cleanupDelay, () async {
      // Only cleanup if still scheduled and app hasn't resumed
      if (_cleanupScheduled && !_appIsClosing) {
        try {
          await _performSecurityCleanup();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Security cleanup error: $e');
          }
        } finally {
          _cleanupScheduled = false;
        }
      }
    });
  }
  
  /// Security cleanup (less aggressive, preserves active temp files)
  Future<void> _performSecurityCleanup() async {
    if (kDebugMode) {
      debugPrint('Performing security temp cleanup (preserving active files)');
    }
    
    try {
      // Only clean old temp files, not recently created ones
      await _cleanupOldTempFiles();
      
      // Clean import/export temp directories (these are safe to clean)
      await _cleanupImportExportTempDirs();
      
      if (kDebugMode) {
        debugPrint('Security cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Security cleanup error: $e');
      }
    }
  }
  
  /// Clean only old temp files (preserve recently created ones for performance)
  Future<void> _cleanupOldTempFiles() async {
    try {
      final systemTempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      
      // Only clean vault_tmp if it's older than 30 minutes (not actively used)
      final vaultTmpInSystem = Directory('${systemTempDir.path}${Platform.pathSeparator}vault_tmp');
      if (await vaultTmpInSystem.exists()) {
        final stat = await vaultTmpInSystem.stat();
        final age = now.difference(stat.modified);
        
        if (age.inMinutes > 30) { // Only clean if older than 30 minutes
          if (kDebugMode) {
            debugPrint('Cleaning old vault_tmp (${age.inMinutes} minutes old)');
          }
          await vaultTmpInSystem.delete(recursive: true);
        } else {
          if (kDebugMode) {
            debugPrint('Preserving recent vault_tmp (${age.inMinutes} minutes old)');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Old temp files cleanup error: $e');
      }
    }
  }
  
  /// Clean import/export temp directories (always safe to clean)
  Future<void> _cleanupImportExportTempDirs() async {
    try {
      final systemTempDir = await getTemporaryDirectory();
      
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          // Only clean import/export related temp dirs, not vault_tmp
          if (name.contains('local_vault_zip_') ||
              name.contains('local_vault_android_export') ||
              name.contains('container_') ||
              name.contains('yomikiru_export')) {
            try {
              if (kDebugMode) {
                debugPrint('Cleaning import/export temp: ${entity.path}');
              }
              await entity.delete(recursive: true);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error cleaning ${entity.path}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Import/export temp cleanup error: $e');
      }
    }
  }
  
  /// Cancel scheduled cleanup to avoid unnecessary work
  void _cancelScheduledCleanup() {
    if (_cleanupScheduled) {
      _cleanupScheduled = false;
      if (kDebugMode) {
        debugPrint('Cancelled scheduled cleanup - app resumed');
      }
    }
  }
  
  /// Immediate comprehensive cleanup (synchronous for app termination)
  void _performImmediateComprehensiveCleanup() {
    if (kDebugMode) {
      debugPrint('App terminating - performing comprehensive cleanup');
    }
    
    try {
      // Clean ALL temp directories since app is closing
      _cleanupAllTempDirectoriesOnClose();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Comprehensive cleanup error: $e');
      }
    }
  }
  
  /// Clean all temp directories when app is actually closing (synchronous)
  void _cleanupAllTempDirectoriesOnClose() {
    try {
      final systemTempDir = Directory.systemTemp;
      
      // Clean vault_tmp completely since app is closing
      final vaultTmpInSystem = Directory('${systemTempDir.path}${Platform.pathSeparator}vault_tmp');
      if (vaultTmpInSystem.existsSync()) {
        if (kDebugMode) {
          debugPrint('Cleaning vault_tmp on app close: ${vaultTmpInSystem.path}');
        }
        vaultTmpInSystem.deleteSync(recursive: true);
      }
      
      // Clean all vault-related temp directories
      try {
        for (final entity in systemTempDir.listSync()) {
          if (entity is Directory) {
            final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
            if (name.contains('vault') || 
                name.contains('local_vault') ||
                name.contains('container_') ||
                name.contains('yomikiru')) {
              try {
                if (kDebugMode) {
                  debugPrint('Cleaning vault temp on close: ${entity.path}');
                }
                entity.deleteSync(recursive: true);
              } catch (e) {
                // Continue with other directories
                if (kDebugMode) {
                  debugPrint('Failed to clean ${entity.path}: $e');
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error listing system temp: $e');
        }
      }
      
      if (kDebugMode) {
        debugPrint('Comprehensive cleanup on app close completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Comprehensive cleanup error: $e');
      }
    }
  }
  
  /// Clean vault-specific temp directory (async, optimized)
  Future<void> _cleanupVaultTempAsync() async {
    try {
      final vaultTempDir = await VaultPaths.tempDir();
      if (await vaultTempDir.exists()) {
        if (kDebugMode) {
          debugPrint('Cleaning vault temp: ${vaultTempDir.path}');
        }
        await vaultTempDir.delete(recursive: true);
      }
    } catch (e) {
      // Silently handle errors to avoid performance impact
      if (kDebugMode) {
        debugPrint('Vault temp cleanup error: $e');
      }
    }
  }
  
  /// Clean all system temp directories (comprehensive async cleanup)
  Future<void> _cleanupAllSystemTempAsync() async {
    try {
      final systemTempDir = await getTemporaryDirectory();
      
      // Clean vault_tmp folder in system temp
      final vaultTmpInSystem = Directory('${systemTempDir.path}${Platform.pathSeparator}vault_tmp');
      if (await vaultTmpInSystem.exists()) {
        if (kDebugMode) {
          debugPrint('Cleaning system vault_tmp: ${vaultTmpInSystem.path}');
        }
        await vaultTmpInSystem.delete(recursive: true);
      }
      
      // Clean any container temp directories
      await _cleanupContainerTempDirs(systemTempDir);
      
      // Clean any zip import temp directories
      await _cleanupZipImportTempDirs(systemTempDir);
      
      // Clean any other vault-related temp directories
      await _cleanupOtherVaultTempDirs(systemTempDir);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('System temp cleanup error: $e');
      }
    }
  }
  
  /// Clean container-related temp directories
  Future<void> _cleanupContainerTempDirs(Directory systemTempDir) async {
    try {
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory && entity.path.contains('container_')) {
          try {
            if (kDebugMode) {
              debugPrint('Cleaning container temp: ${entity.path}');
            }
            await entity.delete(recursive: true);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error cleaning container temp ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cleaning container temp directories: $e');
      }
    }
  }
  
  /// Clean ZIP import temp directories
  Future<void> _cleanupZipImportTempDirs(Directory systemTempDir) async {
    try {
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory && (
            entity.path.contains('local_vault_zip_') ||
            entity.path.contains('local_vault_android_export')
        )) {
          try {
            if (kDebugMode) {
              debugPrint('Cleaning zip import temp: ${entity.path}');
            }
            await entity.delete(recursive: true);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error cleaning zip import temp ${entity.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cleaning ZIP import temp directories: $e');
      }
    }
  }
  
  /// Clean other vault-related temp directories
  Future<void> _cleanupOtherVaultTempDirs(Directory systemTempDir) async {
    try {
      await for (final entity in systemTempDir.list()) {
        if (entity is Directory) {
          final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
          // Clean any directory that might be vault-related
          if (name.contains('vault') || 
              name.contains('yomikiru') ||
              name.contains('manga_reader') ||
              name.startsWith('local_vault_')) {
            try {
              if (kDebugMode) {
                debugPrint('Cleaning vault-related temp: ${entity.path}');
              }
              await entity.delete(recursive: true);
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Error cleaning vault temp ${entity.path}: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error cleaning other vault temp directories: $e');
      }
    }
  }
  
  /// Manual cleanup method for settings screen (comprehensive but safe)
  Future<void> performManualCleanup() async {
    if (kDebugMode) {
      debugPrint('Manual comprehensive temp cleanup initiated');
    }
    
    try {
      // Comprehensive cleanup for manual operation
      await _cleanupVaultTempAsync();
      await _cleanupAllSystemTempAsync();
      await _cleanupApplicationCacheAsync();
      
      // Also clean any Android-specific temp directories
      if (Platform.isAndroid) {
        await _cleanupAndroidSpecificTempAsync();
      }
      
      if (kDebugMode) {
        debugPrint('Manual comprehensive cleanup completed');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Manual cleanup error: $e');
      }
      rethrow;
    }
  }
  
  /// Clean Android-specific temp directories
  Future<void> _cleanupAndroidSpecificTempAsync() async {
    try {
      // Clean external cache directory if available
      final externalCacheDir = await getExternalCacheDirectories();
      if (externalCacheDir != null) {
        for (final dir in externalCacheDir) {
          try {
            // Clean vault-related files in external cache
            await for (final entity in dir.list()) {
              if (entity is Directory || entity is File) {
                final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
                if (name.contains('vault') || name.contains('local_vault')) {
                  try {
                    if (kDebugMode) {
                      debugPrint('Cleaning Android external cache: ${entity.path}');
                    }
                    await entity.delete(recursive: true);
                  } catch (e) {
                    if (kDebugMode) {
                      debugPrint('Error cleaning Android cache ${entity.path}: $e');
                    }
                  }
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Error accessing external cache dir ${dir.path}: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Android-specific cleanup error: $e');
      }
    }
  }
  
  /// Clean application cache directory (comprehensive)
  Future<void> _cleanupApplicationCacheAsync() async {
    try {
      final cacheDir = await getApplicationCacheDirectory();
      
      // Clean local_vault_zip_* directories
      await for (final entity in cacheDir.list()) {
        if (entity is Directory && entity.path.contains('local_vault_zip_')) {
          try {
            if (kDebugMode) {
              debugPrint('Cleaning cache: ${entity.path}');
            }
            await entity.delete(recursive: true);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Cache cleanup error: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Application cache cleanup error: $e');
      }
    }
  }
  
  /// Get temp directory usage statistics (lightweight)
  Future<TempDirectoryStats> getTempDirectoryStats() async {
    int totalFiles = 0;
    int totalSizeBytes = 0;
    final directories = <String>[];
    
    try {
      // Check vault temp directory
      final vaultTempDir = await VaultPaths.tempDir();
      if (await vaultTempDir.exists()) {
        final stats = await _getDirectoryStats(vaultTempDir);
        totalFiles += stats.fileCount;
        totalSizeBytes += stats.sizeBytes;
        directories.add('Vault Temp: ${stats.fileCount} files, ${(stats.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB');
      }
      
      // Check system temp directory (focused check)
      final systemTempDir = await getTemporaryDirectory();
      final vaultTmpInSystem = Directory('${systemTempDir.path}${Platform.pathSeparator}vault_tmp');
      if (await vaultTmpInSystem.exists()) {
        final stats = await _getDirectoryStats(vaultTmpInSystem);
        totalFiles += stats.fileCount;
        totalSizeBytes += stats.sizeBytes;
        directories.add('System Vault Temp: ${stats.fileCount} files, ${(stats.sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Stats error: $e');
      }
    }
    
    return TempDirectoryStats(
      totalFiles: totalFiles,
      totalSizeBytes: totalSizeBytes,
      directories: directories,
    );
  }
  
  /// Get statistics for a specific directory (optimized)
  Future<DirectoryStats> _getDirectoryStats(Directory dir) async {
    int fileCount = 0;
    int sizeBytes = 0;
    
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          try {
            sizeBytes += await entity.length();
          } catch (e) {
            // Skip inaccessible files
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Directory stats error: $e');
      }
    }
    
    return DirectoryStats(fileCount: fileCount, sizeBytes: sizeBytes);
  }
  
  /// Final cleanup when app is being disposed (synchronous)
  void performFinalCleanup() {
    if (kDebugMode) {
      debugPrint('Performing final cleanup on app disposal');
    }
    
    _appIsClosing = true; // Mark app as closing
    
    try {
      _performImmediateComprehensiveCleanup();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Final cleanup error: $e');
      }
    }
  }
  
  /// Dispose resources (lightweight)
  void dispose() {
    // Perform final cleanup before disposing
    performFinalCleanup();
    
    _cleanupScheduled = false;
    if (kDebugMode) {
      debugPrint('AppLifecycleService disposed');
    }
  }
}

/// Statistics for a directory
class DirectoryStats {
  final int fileCount;
  final int sizeBytes;
  
  DirectoryStats({required this.fileCount, required this.sizeBytes});
}

/// Statistics for all temp directories
class TempDirectoryStats {
  final int totalFiles;
  final int totalSizeBytes;
  final List<String> directories;
  
  TempDirectoryStats({
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.directories,
  });
  
  String get formattedSize => '${(totalSizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}