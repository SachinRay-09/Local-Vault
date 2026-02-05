import 'package:flutter/material.dart';

import '../services/app_lifecycle_service.dart';
import '../ui/auth/auth_gate.dart';

class VaultApp extends StatefulWidget {
  const VaultApp({super.key});

  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> with WidgetsBindingObserver {
  late final AppLifecycleService _lifecycleService;

  @override
  void initState() {
    super.initState();
    _lifecycleService = AppLifecycleService();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleService.initialize();
  }

  @override
  void dispose() {
    // Perform final cleanup before app termination
    try {
      _lifecycleService.performFinalCleanup();
    } catch (e) {
      debugPrint('Final cleanup error: $e');
    }
    
    WidgetsBinding.instance.removeObserver(this);
    _lifecycleService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _lifecycleService.handleLifecycleChange(state);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5B5BD6),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Local Vault',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardTheme(
          color: colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

