import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'app/app.dart';
import 'db/isar_db.dart';
import 'services/memory_management_service.dart';

// Conditional import for FVP (Windows only)
import 'fvp_stub.dart' if (dart.library.io) 'fvp_real.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register FVP for Windows only (hardware-accelerated video playback)
  if (!kIsWeb && Platform.isWindows) {
    registerFvp();
  }

  // PHASE 2: Memory Management - Optimize memory settings
  MemoryManagementService.instance.optimizeMemorySettings();

  // PHASE 3: Progressive Loading & Battery Awareness - Services initialized lazily when first used

  // PHASE 2A.3: Progressive Image Loading - Optimized cache management
  PaintingBinding.instance.imageCache.maximumSize =
      50; // Increased for better performance
  PaintingBinding.instance.imageCache.maximumSizeBytes =
      50 * 1024 * 1024; // 50MB balanced cache

  // Clear any existing cache to start fresh
  PaintingBinding.instance.imageCache.clear();

  // Performance monitoring disabled due to memory leak
  // TODO: Implement memory-safe monitoring in Phase 2C

  await IsarDb.open();
  runApp(const VaultApp());
}
