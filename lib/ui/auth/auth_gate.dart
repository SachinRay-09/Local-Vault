import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../services/auth_service.dart';
import '../../services/secure_storage_service.dart';
import '../home/home_screen.dart';
import '../mobile/mobile_home_screen.dart';
import 'login_screen.dart';
import 'setup_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final AuthService _auth = AuthService(secureStorage: SecureStorageService.instance);
  late Future<AuthState> _load = _auth.loadState();

  Future<void> _reload() async {
    setState(() {
      _load = _auth.loadState();
    });
  }

  /// Get the appropriate home screen based on platform
  Widget _getHomeScreen() {
    // Use mobile interface on Android, desktop interface on other platforms
    if (defaultTargetPlatform == TargetPlatform.android) {
      return const MobileHomeScreen();
    } else {
      return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AuthState>(
      future: _load,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final state = snapshot.data!;
        if (!state.isSetup) {
          return SetupScreen(
            auth: _auth,
            onDone: _reload,
          );
        }

        return LoginScreen(
          auth: _auth,
          onUnlocked: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => _getHomeScreen(), // Use platform-appropriate interface
              ),
            );
          },
          onResetDone: _reload,
        );
      },
    );
  }
}

