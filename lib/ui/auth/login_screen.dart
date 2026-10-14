import 'package:flutter/material.dart';

import '../../app/auth_session.dart';
import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';
import 'recovery_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.auth,
    required this.onUnlocked,
    required this.onResetDone,
  });

  final AuthService auth;
  final VoidCallback onUnlocked;
  final Future<void> Function() onResetDone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _lockHint;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() {
      _error = null;
      _busy = true;
    });
    final swUnlock = Stopwatch()..start();
    try {
      // Check lockout before doing any work.
      final remaining = await widget.auth.lockRemaining();
      if (remaining != null && remaining.inSeconds > 0) {
        if (!mounted) return;
        setState(() {
          _lockHint = 'Locked. Try again in ${remaining.inSeconds}s.';
          _busy = false;
        });
        return;
      }

      // KDF runs in a background isolate inside AuthSession.unlock — the UI
      // thread (and spinner) remain responsive while waiting.
      await AuthSession.unlock(_password.text);

      swUnlock.stop();
      debugPrint('[Benchmark] Total unlock: ${swUnlock.elapsedMilliseconds}ms');

      if (!mounted) return;
      widget.onUnlocked();
    } on StateError catch (e) {
      if (!mounted) return;
      final r = await SecureStorageService.instance.lockRemaining();
      setState(() {
        _error = e.message;
        _lockHint = r == null ? null : 'Locked. Try again in ${r.inSeconds}s.';
      });
    } on ArgumentError {
      // Wrong password — lock hint may have been updated by recordAuthAttempt.
      if (!mounted) return;
      final r = await SecureStorageService.instance.lockRemaining();
      setState(() {
        _error = 'Incorrect password.';
        _lockHint = r == null ? null : 'Locked. Try again in ${r.inSeconds}s.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    setState(() => _busy = true);
    final questions = await widget.auth.getSecurityQuestionTexts();
    if (mounted) setState(() => _busy = false);
    if (!mounted) return;
    if (questions == null) {
      setState(() => _error = 'Recovery questions are not configured.');
      return;
    }

    final didReset = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecoveryScreen(
          auth: widget.auth,
          q1: questions['q1']!,
          q2: questions['q2']!,
        ),
      ),
    );

    if (didReset == true) {
      await widget.onResetDone();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unlock vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  onSubmitted: (_) => _busy ? null : _unlock(),
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (_lockHint != null) ...[
                  const SizedBox(height: 6),
                  Text(_lockHint!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _unlock,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : const Text('Unlock'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Forgot password?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
