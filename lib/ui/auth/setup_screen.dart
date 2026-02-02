import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.auth,
    required this.onDone,
  });

  final AuthService auth;
  final Future<void> Function() onDone;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  final _q1Text = TextEditingController(text: 'What is your favorite city?');
  final _q1Answer = TextEditingController();
  final _q2Text = TextEditingController(text: 'What is your first pet name?');
  final _q2Answer = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _password2.dispose();
    _q1Text.dispose();
    _q1Answer.dispose();
    _q2Text.dispose();
    _q2Answer.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await widget.auth.setup(
        password: _password.text,
        q1Text: _q1Text.text.trim(),
        q1Answer: _q1Answer.text.trim(),
        q2Text: _q2Text.text.trim(),
        q2Answer: _q2Answer.text.trim(),
      );
      await widget.onDone();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set up vault')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text('Create an app password to unlock your vault.'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.length < 6) return 'Use at least 6 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password2,
                    decoration: const InputDecoration(labelText: 'Confirm password'),
                    obscureText: true,
                    validator: (v) {
                      if (v != _password.text) return 'Passwords do not match.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Recovery questions (needed if you forget password):'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q1Text,
                    decoration: const InputDecoration(labelText: 'Question 1'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q1Answer,
                    decoration: const InputDecoration(labelText: 'Answer 1'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q2Text,
                    decoration: const InputDecoration(labelText: 'Question 2'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q2Answer,
                    decoration: const InputDecoration(labelText: 'Answer 2'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const CircularProgressIndicator() : const Text('Create vault'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

