import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../app/vault_theme.dart';
import '../../services/app_lifecycle_service.dart';
import '../../services/settings_service.dart';
import '../auth/auth_gate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();

  VaultStats? _stats;
  int? _maxBytes;
  ThemeMode _currentThemeMode = ThemeMode.system;

  final _limitMbController = TextEditingController();
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _limitMbController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    final s = await _settings.getOrCreate();
    final stats = await _settings.stats();
    final rawTheme = await _settings.getThemeMode();
    if (!mounted) return;

    _maxBytes = s.maxStorageBytes;
    _stats = stats;
    _currentThemeMode = parseThemeMode(rawTheme);
    _limitMbController.text = _maxBytes == null
        ? ''
        : (_maxBytes! / (1024 * 1024)).toStringAsFixed(0);

    setState(() => _busy = false);
  }

  Future<void> _saveLimit() async {
    final raw = _limitMbController.text.trim();
    if (raw.isEmpty) {
      await _settings.setMaxStorageBytes(null);
      await _load();
      return;
    }

    final mb = int.tryParse(raw);
    if (mb == null || mb < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid MB number')));
      return;
    }
    await _settings.setMaxStorageBytes(mb * 1024 * 1024);
    await _load();
  }

  Future<void> _clearTemp() async {
    try {
      final lifecycleService = AppLifecycleService();
      await lifecycleService.performManualCleanup();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('All temporary files cleared securely')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clearing temp files: $e')));
    }
  }

  void _lockVault() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
  }

  static String _fmtBytes(int bytes) {
    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;
    if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(2)} GB';
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(2)} MB';
    if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(2)} KB';
    return '$bytes B';
  }

  String _themeModeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _busy
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Vault',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            if (stats != null) ...[
                              Text('Folders: ${stats.folderCount}'),
                              Text('Files: ${stats.fileCount}'),
                              Text('Used: ${_fmtBytes(stats.totalBytes)}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Appearance',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            const Text(
                                'Follow the device theme, or lock to light or dark.'),
                            const SizedBox(height: 12),
                            SegmentedButton<ThemeMode>(
                              segments: const [
                                ButtonSegment(
                                  value: ThemeMode.system,
                                  label: Text('System'),
                                  icon: Icon(Icons.brightness_auto),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.light,
                                  label: Text('Light'),
                                  icon: Icon(Icons.light_mode),
                                ),
                                ButtonSegment(
                                  value: ThemeMode.dark,
                                  label: Text('Dark'),
                                  icon: Icon(Icons.dark_mode),
                                ),
                              ],
                              selected: {_currentThemeMode},
                              onSelectionChanged: (newVal) async {
                                final mode = newVal.first;
                                setState(() => _currentThemeMode = mode);
                                await _settings
                                    .setThemeMode(_themeModeToString(mode));
                                VaultApp.themeMode.value = mode;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Storage limit',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _limitMbController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max storage (MB)',
                                helperText: 'Leave empty for unlimited',
                                suffixText: _maxBytes == null
                                    ? null
                                    : _fmtBytes(_maxBytes!),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                  onPressed: _saveLimit,
                                  child: const Text('Save')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Maintenance',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _clearTemp,
                              icon:
                                  const Icon(Icons.cleaning_services_outlined),
                              label: const Text('Clear temp cache'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _lockVault,
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Lock vault'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
