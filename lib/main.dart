import 'package:flutter/material.dart';

import 'app/app.dart';
import 'db/isar_db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IsarDb.open();
  runApp(const VaultApp());
}
