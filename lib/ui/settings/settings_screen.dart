import 'package:flutter/material.dart';

import '../../services/settings_service.dart';
import '../../services/vault_paths.dart';
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
    if (!mounted) return;

    _maxBytes = s.maxStorageBytes;
    _stats = stats;
    _limitMbController.text = _maxBytes == null ? '' : (_maxBytes! / (1024 * 1024)).toStringAsFixed(0);

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid MB number')));
      return;
    }
    await _settings.setMaxStorageBytes(mb * 1024 * 1024);
    await _load();
  }

  Future<void> _clearTemp() async {
    final dir = await VaultPaths.ensureTempDir();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
    await VaultPaths.ensureTempDir();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temp cache cleared')));
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
                            Text('Vault', style: Theme.of(context).textTheme.titleMedium),
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
                            Text('Storage limit', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _limitMbController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Max storage (MB)',
                                helperText: 'Leave empty for unlimited',
                                suffixText: _maxBytes == null ? null : _fmtBytes(_maxBytes!),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(onPressed: _saveLimit, child: const Text('Save')),
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
                            Text('Maintenance', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _clearTemp,
                              icon: const Icon(Icons.cleaning_services_outlined),
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

