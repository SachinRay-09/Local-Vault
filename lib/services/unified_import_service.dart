import 'dart:io';

import 'package:flutter/foundation.dart';

import 'encryption_strategy_service.dart';
import 'enhanced_vault_repository.dart';
import 'import_export_service.dart';
import 'saf_zip_import_service.dart';
import 'thermal_protection_service.dart';

/// Unified import service that combines all import methods with smart encryption
@Deprecated(
    'Quarantined Phase 1 — use BulkImportService (desktop) or ImportCoordinator (Phase 2) instead')
class UnifiedImportService {
  final EnhancedVaultRepository _enhancedRepo;
  final ImportExportService _legacyImport;
  final SafZipImportService _safImport;
  final ThermalProtectionService _thermal = ThermalProtectionService.instance;

  UnifiedImportService({
    required EnhancedVaultRepository enhancedRepo,
  })  : _enhancedRepo = enhancedRepo,
        _legacyImport = ImportExportService(
          repo: enhancedRepo,
          crypto: enhancedRepo.crypto,
          secureStorage: enhancedRepo.secureStorage,
        ),
        _safImport = SafZipImportService(repo: enhancedRepo);

  /// Import multiple files with automatic strategy selection
  Future<UnifiedImportResult> importFiles({
    required List<File> files,
    required int? destinationFolderId,
    String? folderName,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Starting smart import process...');

      // Use enhanced repository for smart bulk import
      final result = await _enhancedRepo.addMultipleMedia(
        sourceFiles: files,
        parentFolderId: destinationFolderId,
        folderName: folderName,
        onProgress: onProgress,
        onStatusUpdate: onStatusUpdate,
      );

      return UnifiedImportResult(
        success: result.success,
        filesImported: result.filesImported ?? 0,
        foldersCreated: result.foldersCreated ?? 0,
        strategy: result.strategy ?? 'Unknown',
        performanceInfo: result.performanceGain ?? '',
        error: result.error,
      );
    } catch (e) {
      debugPrint('Unified import failed: $e');
      return UnifiedImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Import ZIP file with SAF support and fallback
  Future<UnifiedImportResult> importZip({
    required String zipPath,
    required String password,
    required int? destinationFolderId,
    Function(double)? onProgress,
    Function(String)? onStatusUpdate,
  }) async {
    try {
      onStatusUpdate?.call('Importing ZIP file...');

      // Try SAF import first (Android 15+ compatible)
      if (Platform.isAndroid) {
        try {
          final zipUri = Uri.file(zipPath);
          final safResult = await _safImport.importFromZipUri(
            zipUri: zipUri,
            password: password,
            destinationFolderId: destinationFolderId,
            onImportComplete: (result) {
              onProgress?.call(1.0);
            },
          );

          return UnifiedImportResult(
            success: true,
            filesImported: safResult.filesImported,
            foldersCreated: safResult.foldersCreated,
            strategy: 'SAF ZIP Import',
            performanceInfo: 'Android 15+ compatible',
          );
        } catch (safError) {
          debugPrint('SAF import failed, trying legacy: $safError');
          onStatusUpdate?.call('SAF import failed, using fallback method...');
        }
      }

      // Fallback to legacy import
      final legacyResult = await _legacyImport.importFromZip(
        zipPath: zipPath,
        password: password,
        destinationFolderId: destinationFolderId,
      );

      return UnifiedImportResult(
        success: true,
        filesImported: legacyResult.filesImported,
        foldersCreated: legacyResult.foldersCreated,
        strategy: 'Legacy ZIP Import',
        performanceInfo: 'Fallback method',
      );
    } catch (e) {
      debugPrint('ZIP import failed: $e');
      return UnifiedImportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Get import strategy preview without actually importing
  Future<ImportStrategyPreview> previewImportStrategy(List<File> files) async {
    try {
      final analysis =
          EncryptionStrategyService.analyzeEncryptionStrategy(files);

      return ImportStrategyPreview(
        recommendedStrategy: analysis.recommendedStrategy,
        reasoning: analysis.reasoning,
        expectedPerformanceGain: analysis.performanceGain,
        expectedMemoryReduction: analysis.memoryReduction,
        fileCount: files.length,
        totalSize: analysis.metrics['totalSize'] ?? 0,
        strategyDescription: EncryptionStrategyService.getStrategyDescription(
          analysis.recommendedStrategy,
          files.length,
        ),
        performanceDescription: EncryptionStrategyService.getPerformanceImpact(
          analysis.performanceGain,
          analysis.memoryReduction,
        ),
      );
    } catch (e) {
      debugPrint('Strategy preview failed: $e');
      return ImportStrategyPreview(
        recommendedStrategy: EncryptionStrategy.individual,
        reasoning: 'Error analyzing files: $e',
        expectedPerformanceGain: 0.0,
        expectedMemoryReduction: 0.0,
        fileCount: files.length,
        totalSize: 0,
        strategyDescription: 'Fallback to individual encryption',
        performanceDescription: 'Standard performance',
      );
    }
  }

  /// Get current thermal status for UI display
  ThermalStatus getCurrentThermalStatus() {
    final state = _thermal.currentState;
    final config = _thermal.getProcessingConfig();

    return ThermalStatus(
      state: state,
      description: ThermalProtectionService.getThermalStateDescription(state),
      color: ThermalProtectionService.getThermalStateColor(state),
      processingConfig: config,
      isThrottling: state != ThermalState.nominal,
    );
  }
}

/// Result of unified import operation
class UnifiedImportResult {
  final bool success;
  final int filesImported;
  final int foldersCreated;
  final String strategy;
  final String performanceInfo;
  final String? error;

  UnifiedImportResult({
    required this.success,
    this.filesImported = 0,
    this.foldersCreated = 0,
    this.strategy = '',
    this.performanceInfo = '',
    this.error,
  });
}

/// Preview of import strategy before execution
class ImportStrategyPreview {
  final EncryptionStrategy recommendedStrategy;
  final String reasoning;
  final double expectedPerformanceGain;
  final double expectedMemoryReduction;
  final int fileCount;
  final int totalSize;
  final String strategyDescription;
  final String performanceDescription;

  ImportStrategyPreview({
    required this.recommendedStrategy,
    required this.reasoning,
    required this.expectedPerformanceGain,
    required this.expectedMemoryReduction,
    required this.fileCount,
    required this.totalSize,
    required this.strategyDescription,
    required this.performanceDescription,
  });
}

/// Current thermal status information
class ThermalStatus {
  final ThermalState state;
  final String description;
  final int color;
  final ProcessingConfig processingConfig;
  final bool isThrottling;

  ThermalStatus({
    required this.state,
    required this.description,
    required this.color,
    required this.processingConfig,
    required this.isThrottling,
  });
}
