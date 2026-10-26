import 'package:flutter/material.dart';

import '../../app/auth_session.dart';

/// Change Password screen (Phase 6, task 6.2).
///
/// Mirrors [SetupScreen]'s structure: Scaffold → AppBar → Center →
/// ConstrainedBox(maxWidth: 520) → Padding → Form → ListView. Calls
/// [AuthSession.changePassword] on submit; an [ArgumentError] from the backend
/// (wrong current password) is surfaced inline on the current-password field,
/// other failures are shown as a general error near the submit button.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _busy = false;
  String? _currentFieldError; // set on ArgumentError from backend
  String? _generalError; // set on StateError/other from backend

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _currentFieldError = null;
      _generalError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _busy = true);
    try {
      await AuthSession.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
      Navigator.pop(context);
    } on ArgumentError {
      if (!mounted) return;
      setState(() => _currentFieldError = 'Incorrect current password.');
      _formKey.currentState!.validate(); // trigger inline error immediately
    } catch (e) {
      if (!mounted) return;
      setState(() => _generalError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _currentCtrl,
                    decoration: InputDecoration(
                      labelText: 'Current password',
                      suffixIcon: IconButton(
                        icon: Icon(_currentObscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _currentObscure = !_currentObscure),
                      ),
                    ),
                    obscureText: _currentObscure,
                    validator: (v) {
                      if ((v ?? '').isEmpty) return 'Required';
                      if (_currentFieldError != null) {
                        return _currentFieldError;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newCtrl,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      suffixIcon: IconButton(
                        icon: Icon(_newObscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _newObscure = !_newObscure),
                      ),
                    ),
                    obscureText: _newObscure,
                    validator: (v) {
                      if ((v ?? '').length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      if (v == _currentCtrl.text) {
                        return 'Must differ from current password.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    decoration: InputDecoration(
                      labelText: 'Confirm new password',
                      suffixIcon: IconButton(
                        icon: Icon(_confirmObscure
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _confirmObscure = !_confirmObscure),
                      ),
                    ),
                    obscureText: _confirmObscure,
                    validator: (v) {
                      if ((v ?? '') != _newCtrl.text) {
                        return 'Passwords do not match.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_generalError != null)
                    Text(
                      _generalError!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : const Text('Change Password'),
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
