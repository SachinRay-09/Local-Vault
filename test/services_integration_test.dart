import 'package:flutter_test/flutter_test.dart';
import 'package:local_vault/services/battery_awareness_service.dart';
import 'package:local_vault/services/enhanced_vault_repository.dart';
import 'package:local_vault/services/file_crypto_service.dart';
import 'package:local_vault/services/hardware_acceleration_service.dart';
import 'package:local_vault/services/memory_management_service.dart';
import 'package:local_vault/services/progressive_loading_service.dart';
import 'package:local_vault/services/secure_storage_service.dart';
import 'package:local_vault/services/thermal_protection_service.dart';

void main() {
  group('Services Integration Tests', () {
    test('Hardware Acceleration Service initializes correctly', () async {
      final service = HardwareAccelerationService.instance;
      // ignore: deprecated_member_use_from_same_package
      await service.initialize();

      expect(service.cpuInfo, isNotEmpty);
      expect(service.getRecommendedStrategy(), isNotNull);
      expect(service.getPerformanceMultiplier(), greaterThan(0));
    });

    test('Memory Management Service works correctly', () async {
      final service = MemoryManagementService.instance;

      service.optimizeMemorySettings();
      final batchSize = service.getOptimalBatchSize();
      expect(batchSize, greaterThan(0));

      final stats = await service.getMemoryStats();
      expect(stats.currentBatchSize, greaterThan(0));

      await service.performMemoryCleanup();
    });

    test('Battery Awareness Service provides valid configurations', () async {
      final service = BatteryAwarenessService.instance;

      final config = await service.getProcessingConfig();
      expect(config.batchSize, greaterThan(0));
      expect(config.delayMs, greaterThanOrEqualTo(0));
      expect(config.strategy, isNotNull);
      expect(config.reasoning, isNotEmpty);

      final stats = await service.getBatteryStats();
      expect(stats.batteryLevel, inInclusiveRange(0, 100));
      expect(stats.currentStrategy, isNotNull);
    });

    test('Progressive Loading Service initializes correctly', () {
      final service = ProgressiveLoadingService.instance;

      final stats = service.getCacheStats();
      expect(stats.thumbnailCount, greaterThanOrEqualTo(0));
      expect(stats.fullImageCount, greaterThanOrEqualTo(0));
      expect(stats.totalCacheSizeBytes, greaterThanOrEqualTo(0));

      service.clearCaches();
      final clearedStats = service.getCacheStats();
      expect(clearedStats.thumbnailCount, equals(0));
      expect(clearedStats.fullImageCount, equals(0));
    });

    test('Thermal Protection Service works correctly', () {
      final service = ThermalProtectionService.instance;

      expect(service.currentState, isNotNull);

      final config = service.getProcessingConfig();
      expect(config.batchSize, greaterThan(0));
      expect(config.delayMs, greaterThanOrEqualTo(0));
      expect(config.shouldPause, isA<bool>());
    });

    test('Enhanced Vault Repository integrates all services', () {
      final repo = EnhancedVaultRepository(
        crypto: const FileCryptoService(),
        secureStorage: SecureStorageService.instance,
      );

      expect(repo, isNotNull);

      // Test that repository can be disposed without errors
      repo.dispose();
    });

    test('All services work together without conflicts', () async {
      // Initialize all services (deprecated but tested here explicitly)
      // ignore: deprecated_member_use_from_same_package
      await HardwareAccelerationService.instance.initialize();
      MemoryManagementService.instance.optimizeMemorySettings();

      // Get configurations from all services
      final hardwareStrategy =
          HardwareAccelerationService.instance.getRecommendedStrategy();
      final memoryBatchSize =
          MemoryManagementService.instance.getOptimalBatchSize();
      final batteryConfig =
          await BatteryAwarenessService.instance.getProcessingConfig();
      final thermalConfig =
          ThermalProtectionService.instance.getProcessingConfig();

      // Verify all services provide valid configurations
      expect(hardwareStrategy, isNotNull);
      expect(memoryBatchSize, greaterThan(0));
      expect(batteryConfig.batchSize, greaterThan(0));
      expect(thermalConfig.batchSize, greaterThan(0));

      // Test progressive loading
      final progressiveStats =
          ProgressiveLoadingService.instance.getCacheStats();
      expect(progressiveStats, isNotNull);

      // Cleanup
      await MemoryManagementService.instance.performMemoryCleanup();
      ProgressiveLoadingService.instance.clearCaches();
    });
  });
}
