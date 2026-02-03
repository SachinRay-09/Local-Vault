import 'package:flutter/material.dart';

import 'app/app.dart';
import 'db/isar_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // EMERGENCY: Aggressive image cache limits to prevent memory leaks
  PaintingBinding.instance.imageCache.maximumSize = 20; // Reduced from 50 to 20
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 * 1024 * 1024; // Reduced to 20MB
  
  // Force immediate garbage collection
  PaintingBinding.instance.imageCache.clear();
  
  // Performance monitoring disabled due to memory leak
  // TODO: Implement memory-safe monitoring later
  
  await IsarDb.open();
  runApp(const VaultApp());
}
