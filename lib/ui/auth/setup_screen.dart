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
                  const SizedBox(height: 8),
                  const Text(
                    'Your password unlocks the app. The vault encryption key is stored in the OS keystore and is separate from your password. Security questions allow resetting your unlock password only — they cannot recover your encrypted data.',
                    style: TextStyle(fontSize: 12),
                  ),
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
                    decoration:
                        const InputDecoration(labelText: 'Confirm password'),
                    obscureText: true,
                    validator: (v) {
                      if (v != _password.text) return 'Passwords do not match.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text(
                      'Recovery questions (needed if you forget password):'),
                  const SizedBox(height: 12),

                  // Question 1 - Dropdown with predefined questions
                  DropdownButtonFormField<String>(
                    value: _q1Text.text.isEmpty ? null : _q1Text.text,
                    decoration:
                        const InputDecoration(labelText: 'Security Question 1'),
                    items: const [
                      DropdownMenuItem(
                          value: 'What is your favorite city?',
                          child: Text('What is your favorite city?')),
                      DropdownMenuItem(
                          value: 'What is your mother\'s maiden name?',
                          child: Text('What is your mother\'s maiden name?')),
                      DropdownMenuItem(
                          value: 'What was the name of your first pet?',
                          child: Text('What was the name of your first pet?')),
                      DropdownMenuItem(
                          value: 'What is your favorite book?',
                          child: Text('What is your favorite book?')),
                      DropdownMenuItem(
                          value: 'What school did you attend?',
                          child: Text('What school did you attend?')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _q1Text.text = value;
                      }
                    },
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please select a question'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q1Answer,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer 1',
                      hintText: 'Enter your answer to the question above',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Question 2 - Dropdown with predefined questions
                  DropdownButtonFormField<String>(
                    value: _q2Text.text.isEmpty ? null : _q2Text.text,
                    decoration:
                        const InputDecoration(labelText: 'Security Question 2'),
                    items: const [
                      DropdownMenuItem(
                          value: 'What is your nickname at home?',
                          child: Text('What is your nickname at home?')),
                      DropdownMenuItem(
                          value: 'What is your favorite movie?',
                          child: Text('What is your favorite movie?')),
                      DropdownMenuItem(
                          value: 'What is your favorite food?',
                          child: Text('What is your favorite food?')),
                      DropdownMenuItem(
                          value: 'What was your childhood address?',
                          child: Text('What was your childhood address?')),
                      DropdownMenuItem(
                          value: 'What is your favorite color?',
                          child: Text('What is your favorite color?')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _q2Text.text = value;
                      }
                    },
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please select a question'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _q2Answer,
                    decoration: const InputDecoration(
                      labelText: 'Your Answer 2',
                      hintText: 'Enter your answer to the question above',
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const CircularProgressIndicator()
                        : const Text('Create vault'),
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
