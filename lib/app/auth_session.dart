import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../services/credential_repository.dart';
import '../services/secure_storage_service.dart';

// ---------------------------------------------------------------------------
// Top-level worker — must be a top-level function to cross isolate boundaries.
// Receives [password, salt (Uint8List), iterations, outLen] as a Record.
// Uses utf8.encode to exactly match SecureStorageService._pbkdf2Sha256.
// ---------------------------------------------------------------------------
Uint8List _pbkdf2Worker((String, Uint8List, int, int) args) {
  final (password, salt, iterations, outLen) = args;
  final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
    ..init(Pbkdf2Parameters(salt, iterations, outLen));
  return derivator.process(Uint8List.fromList(utf8.encode(password)));
}

/// Holds the in-memory DEK derived after a successful unlock.
///
/// Lifecycle:
/// - Created by [AuthSession.unlock].
/// - Cleared automatically when the app is paused for longer than
///   [gracePeriod] (default 5 minutes).
/// - [AuthSession.current] is set on unlock and null'd on lock.
class AuthSession with WidgetsBindingObserver {
  AuthSession._(this.dek);

  /// In-memory data-encryption key.  Zeroed by [lock].
  Uint8List dek;

  /// Grace period before auto-lock after app pause.
  static Duration gracePeriod = const Duration(minutes: 5);

  /// The currently active session, or null when locked.
  static AuthSession? current;

  Timer? _lockTimer;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Derives the DEK from [password] in a background isolate and stores it.
  ///
  /// Also updates the lock-out state in [SecureStorageService] so brute-force
  /// protection continues to work identically to the previous code path.
  ///
  /// Returns the new session on success, or throws on auth failure.
  static Future<AuthSession> unlock(String password) async {
    final repo = CredentialRepository();
    final storage = SecureStorageService.instance;

    // Honour any active lockout before doing any work.
    if (await storage.isLockedOut()) {
      throw StateError('Too many failed attempts. Try again later.');
    }

    final saltBytes = await repo.loadSalt();
    final storedHash = await repo.loadPasswordHash();

    if (saltBytes == null || storedHash == null) {
      throw StateError('Vault is not set up — no stored credentials found.');
    }

    final iters = await repo.loadIterations() ?? 120000;
    const outLen = 32;

    // Run KDF in a background isolate so the UI thread stays responsive.
    final derived = await Isolate.run(
      () => _pbkdf2Worker((password, saltBytes, iters, outLen)),
    );

    final ok = await repo.verifyHash(derived, storedHash);

    // Update brute-force lockout counters (same logic as SecureStorageService).
    await storage.recordAuthAttempt(ok);

    if (!ok) {
      throw ArgumentError('Incorrect password.');
    }

    // Tear down any previous session before replacing it.
    current?.lock();

    // Store the actual master key (not the PBKDF2-derived key) so that
    // Phase 5 migration can wrap it as the DEK.  The derived key was only
    // needed to verify the password hash above.
    final masterKeyBytes = await repo.loadMasterKey();
    if (masterKeyBytes == null) {
      throw StateError('No master key found in secure storage.');
    }

    final session = AuthSession._(masterKeyBytes);
    current = session;
    WidgetsBinding.instance.addObserver(session);
    return session;
  }

  /// Zero-fills [dek], unregisters the lifecycle observer, and clears [current].
  void lock() {
    _lockTimer?.cancel();
    _lockTimer = null;

    // Zero the key material in place.
    dek.fillRange(0, dek.length, 0);
    dek = Uint8List(0);

    WidgetsBinding.instance.removeObserver(this);

    if (current == this) {
      current = null;
    }

    debugPrint('[AuthSession] Session locked.');
  }

  // ---------------------------------------------------------------------------
  // WidgetsBindingObserver
  // ---------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _scheduleLock();
    } else if (state == AppLifecycleState.resumed) {
      _cancelScheduledLock();
    }
  }

  void _scheduleLock() {
    _lockTimer?.cancel();
    _lockTimer = Timer(gracePeriod, () {
      debugPrint('[AuthSession] Grace period elapsed — locking session.');
      lock();
    });
  }

  void _cancelScheduledLock() {
    _lockTimer?.cancel();
    _lockTimer = null;
  }
}
