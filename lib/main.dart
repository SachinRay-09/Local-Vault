import 'package:flutter/material.dart';

import 'app/app.dart';
import 'db/isar_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // PHASE 2A: Optimized image cache for performance balance
  PaintingBinding.instance.imageCache.maximumSize = 30; // Increased from 20 to 30
  PaintingBinding.instance.imageCache.maximumSizeBytes = 30 * 1024 * 1024; // 30MB for better performance
  
  // Force immediate garbage collection
  PaintingBinding.instance.imageCache.clear();
  
  // Performance monitoring disabled due to memory leak
  // TODO: Implement memory-safe monitoring later
  
  await IsarDb.open();
  runApp(const VaultApp());
}
