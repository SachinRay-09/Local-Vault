import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({
    super.key,
    required this.auth,
    required this.q1,
    required this.q2,
  });

  final AuthService auth;
  final String q1;
  final String q2;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _a1 = TextEditingController();
  final _a2 = TextEditingController();
  final _newPassword = TextEditingController();
  final _newPassword2 = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _a1.dispose();
    _a2.dispose();
    _newPassword.dispose();
    _newPassword2.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    setState(() => _error = null);
    if (_newPassword.text.trim().length < 6) {
      setState(() => _error = 'Use at least 6 characters.');
      return;
    }
    if (_newPassword.text != _newPassword2.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() => _busy = true);
    try {
      final ok = await widget.auth.verifySecurityAnswers(
        q1Answer: _a1.text.trim(),
        q2Answer: _a2.text.trim(),
      );
      if (!ok) {
        setState(() => _error = 'Incorrect answers.');
        return;
      }

      await widget.auth.resetPassword(_newPassword.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recover vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Text(widget.q1),
                const SizedBox(height: 8),
                TextField(controller: _a1, decoration: const InputDecoration(labelText: 'Answer 1')),
                const SizedBox(height: 16),
                Text(widget.q2),
                const SizedBox(height: 8),
                TextField(controller: _a2, decoration: const InputDecoration(labelText: 'Answer 2')),
                const SizedBox(height: 24),
                const Text('Set a new password:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPassword,
                  decoration: const InputDecoration(labelText: 'New password'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _newPassword2,
                  decoration: const InputDecoration(labelText: 'Confirm new password'),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _busy ? null : _reset,
                  child: _busy ? const CircularProgressIndicator() : const Text('Reset password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

