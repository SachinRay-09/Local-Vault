import 'dart:io';

import 'package:flutter/material.dart';

import '../models/operation_job.dart';
import '../models/operation_job_item.dart';
import '../services/app_lifecycle_service.dart';
import '../services/blob_store.dart';
import '../services/job_repository.dart';
import '../services/settings_service.dart';
import '../ui/auth/auth_gate.dart';
import 'vault_theme.dart';

class VaultApp extends StatefulWidget {
  const VaultApp({super.key});

  /// Process-global theme notifier. Default: ThemeMode.system.
  /// Updated after first frame from persisted AppSettings.
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.system);

  @override
  State<VaultApp> createState() => _VaultAppState();
}

class _VaultAppState extends State<VaultApp> with WidgetsBindingObserver {
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;
  late final AppLifecycleService _lifecycleService;

  @override
  void initState() {
    super.initState();
    const seed = Color(0xFF5B5BD6);
    _lightTheme = buildVaultTheme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light));
    _darkTheme = buildVaultTheme(
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

    _lifecycleService = AppLifecycleService();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleService.initialize();

    // Load persisted theme, then run crash recovery after the first frame so
    // the navigator context is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final raw = await SettingsService().getThemeMode();
        VaultApp.themeMode.value = parseThemeMode(raw);
      } catch (e) {
        debugPrint('[App] Theme load failed: $e');
      }
      try {
        await _checkInterruptedJobs();
      } catch (e) {
        debugPrint('[App] Crash recovery check failed: $e');
      }
    });
  }

  @override
  void dispose() {
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

  // ---------------------------------------------------------------------------
  // Crash recovery — Phase 2: Discard only.
  // ---------------------------------------------------------------------------

  Future<void> _checkInterruptedJobs() async {
    if (!mounted) return;

    final jobRepo = JobRepository();
    final interrupted = await jobRepo.findInterruptedJobs();
    if (interrupted.isEmpty) return;

    // Collect items that have partial blobs on disk.
    final blobStore = BlobStore();
    final partialItems = <OperationJobItem>[];

    for (final job in interrupted) {
      final items = await jobRepo.findPendingOrRunningItems(job.id);
      for (final item in items) {
        final partial = item.partialBlobPath;
        if (partial != null && File(partial).existsSync()) {
          partialItems.add(item);
        }
      }
    }

    if (!mounted) return;
    if (partialItems.isEmpty) {
      // No partial blobs — just mark jobs as failed and move on.
      for (final job in interrupted) {
        await jobRepo.markJobState(job.id, JobState.failed);
      }
      return;
    }

    // Show dialog listing the interrupted items.
    final shouldDiscard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InterruptedJobsDialog(itemCount: partialItems.length),
    );

    if (shouldDiscard != true) return;

    // Discard: delete partial blobs, mark items skipped.
    for (final item in partialItems) {
      await blobStore.deleteBlobIfExists(item.blobId);
      await jobRepo.markJobItemState(item.id, JobItemState.skipped);
    }

    // Mark all interrupted jobs as failed.
    for (final job in interrupted) {
      await jobRepo.markJobState(job.id, JobState.failed);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Interrupted import data cleaned up.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: VaultApp.themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Local Vault',
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: mode,
        home: const AuthGate(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog
// ---------------------------------------------------------------------------

class _InterruptedJobsDialog extends StatelessWidget {
  const _InterruptedJobsDialog({required this.itemCount});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Interrupted Import Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The app was interrupted during a previous import. '
            '$itemCount file(s) have incomplete data on disk.',
          ),
          const SizedBox(height: 12),
          const Text(
            'These partial files will be discarded. '
            // TODO(Phase-3): Add "Resume" option once SecureStorageService
            // is accessible here before authentication.
            'Full resume support is planned for Phase 3.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Discard & Clean Up'),
        ),
      ],
    );
  }
}
