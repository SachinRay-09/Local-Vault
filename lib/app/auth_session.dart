import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart' show Pbkdf2Parameters;
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

import '../models/vault_key_envelope.dart';
import '../services/credential_repository.dart';
import '../services/dart_crypto_engine.dart';
import '../services/secure_storage_service.dart';
import '../services/window_security_service.dart';

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

  /// Unlocks the vault with [password].
  ///
  /// Phase 5 paths:
  /// - **Envelope path** (hasEnvelope == true): derives KEK via PBKDF2, unwraps
  ///   DEK from envelope.  Wrong password → [ArgumentError].
  /// - **Legacy path** (hasEnvelope == false, first login after Phase 5 deploy):
  ///   loads master key from secure storage, attempts silent migration to an
  ///   envelope (non-fatal if migration fails).
  ///
  /// Returns the new [AuthSession] on success.  Throws on auth failure.
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

    // If an envelope is present, we can skip the hash-based KDF verification
    // and rely solely on GCM tag authentication during DEK unwrap — this saves
    // one full PBKDF2 run (~120k iterations) on unlock (OPT-003).
    if (await repo.hasEnvelope()) {
      // ── Phase 5+ path: derive KEK, unwrap DEK from envelope ──
      final envelope = await repo.loadEnvelope();
      if (envelope == null) {
        // Envelope present but unparseable — fall back to legacy + hash check.
        debugPrint(
            '[AuthSession] Envelope unreadable; falling back to legacy.');
        return _legacyUnlockWithHashCheck(
            password, saltBytes, storedHash, iters, repo, storage);
      }

      final kek = await DartCryptoEngine.deriveKek(
          password, envelope.saltBytes, envelope.iterations);
      // unwrapDek throws AuthenticationFailure on tag mismatch (wrong password).
      final Uint8List dek;
      try {
        dek = DartCryptoEngine.unwrapDek(envelope.wrappedDekBytes,
            envelope.tagBytes, envelope.nonceBytes, kek);
      } on AuthenticationFailure {
        kek.fillRange(0, kek.length, 0);
        // GCM auth failure = wrong password.
        await storage.recordAuthAttempt(false);
        throw ArgumentError('Incorrect password.');
      } finally {
        kek.fillRange(0, kek.length, 0);
      }

      await storage.recordAuthAttempt(true);
      // Tear down any previous session before replacing it.
      current?.lock();
      final session = AuthSession._(dek);
      current = session;
      WidgetsBinding.instance.addObserver(session);
      return session;
    }

    // No envelope — run PBKDF2 hash check + legacy path.
    return _legacyUnlockWithHashCheck(
        password, saltBytes, storedHash, iters, repo, storage);
  }

  /// Hash-check path used when no envelope exists (first login or corrupted envelope).
  static Future<AuthSession> _legacyUnlockWithHashCheck(
    String password,
    Uint8List saltBytes,
    String storedHash,
    int iters,
    CredentialRepository repo,
    SecureStorageService storage,
  ) async {
    // Run KDF in a background isolate so the UI thread stays responsive.
    final derived = await Isolate.run(
      () => _pbkdf2Worker((password, saltBytes, iters, 32)),
    );

    final ok = await repo.verifyHash(derived, storedHash);

    // Update brute-force lockout counters.
    await storage.recordAuthAttempt(ok);

    if (!ok) {
      throw ArgumentError('Incorrect password.');
    }

    // Tear down any previous session before replacing it.
    current?.lock();

    return _legacyUnlock(password, repo, storage);
  }

  /// Legacy path: loads master key from secure storage, then silently migrates
  /// to Phase 5 envelope format (non-fatal).
  static Future<AuthSession> _legacyUnlock(
    String password,
    CredentialRepository repo,
    SecureStorageService storage,
  ) async {
    final masterKey = await repo.loadMasterKey();
    if (masterKey == null) {
      throw StateError('No master key found in secure storage.');
    }

    // Attempt silent migration to Phase 5 envelope (non-fatal on failure).
    try {
      await _migrateToEnvelope(password, masterKey, repo);
    } catch (e) {
      debugPrint('[AuthSession] Migration to envelope failed (non-fatal): $e');
      // Continue with legacy key; migration will be retried on next login.
    }

    final session = AuthSession._(masterKey);
    current = session;
    WidgetsBinding.instance.addObserver(session);
    return session;
  }

  /// Silently migrates a legacy vault to Phase 5 envelope storage.
  ///
  /// Rollback ordering invariant:
  ///   storeRollbackMarker BEFORE storeEnvelope — always.
  /// On any failure after storeRollbackMarker + storeEnvelope, deleteEnvelope.
  /// On verification failure: deleteEnvelope + deleteRollbackMarker.
  /// On success: deleteRollbackMarker (master_key_b64 kept for one release
  ///   cycle as belt-and-suspenders; remove in Phase 6).
  static Future<void> _migrateToEnvelope(
    String password,
    Uint8List masterKey,
    CredentialRepository repo,
  ) async {
    const kekIterations = 200000;
    final salt = _randomBytes(16);

    // 1. Derive KEK on isolate (off UI thread).
    final kek = await DartCryptoEngine.deriveKek(password, salt, kekIterations);

    // 2. Wrap the master key as the DEK.
    final wrapped = DartCryptoEngine.wrapDek(masterKey, kek);

    // 3. Write ROLLBACK MARKER FIRST (invariant).
    await repo.storeRollbackMarker(masterKey);

    // 4. Build and store the new envelope.
    final envelope = VaultKeyEnvelope(
      vaultVersion: 2,
      kdfAlgorithm: 'pbkdf2_sha256',
      kdfSalt: base64Encode(salt),
      kdfParams: {'iterations': kekIterations},
      wrappedDek: base64Encode(wrapped.ciphertext),
      wrappedDekNonce: base64Encode(wrapped.nonce),
      wrappedDekTag: base64Encode(wrapped.tag),
    );
    await repo.storeEnvelope(envelope);

    // 5. Verify: re-derive KEK, unwrap, compare with original masterKey.
    final kek2 =
        await DartCryptoEngine.deriveKek(password, salt, kekIterations);
    final Uint8List dek2;
    try {
      dek2 = DartCryptoEngine.unwrapDek(
          wrapped.ciphertext, wrapped.tag, wrapped.nonce, kek2);
    } on AuthenticationFailure catch (e) {
      // Verification failed — roll back completely.
      await repo.deleteEnvelope();
      await repo.deleteRollbackMarker();
      throw StateError('Migration verification failed: $e');
    } finally {
      kek2.fillRange(0, kek2.length, 0);
    }

    if (!_bytesEqual(dek2, masterKey)) {
      await repo.deleteEnvelope();
      await repo.deleteRollbackMarker();
      throw StateError('Migration verification: DEK round-trip mismatch.');
    }

    // 6. Zero ephemeral key material.
    kek.fillRange(0, kek.length, 0);

    // 7. Success — delete rollback marker.
    //    master_key_b64 is kept for one release (removed in Phase 6).
    await repo.deleteRollbackMarker();
    debugPrint('[AuthSession] Phase 5 migration complete.');
  }

  /// Changes the vault password.
  ///
  /// Steps:
  ///   1. Verify current password (re-runs KDF + hash check).
  ///   2. Load existing envelope OR fall back to master key.
  ///   3. Derive current KEK, unwrap DEK.
  ///   4. Derive new KEK with fresh random salt.
  ///   5. storeRollbackMarker BEFORE storeEnvelope.
  ///   6. wrapDek with new KEK → store new envelope.
  ///   7. Verify new envelope (re-derive + unwrap + compare).
  ///   8. On success: deleteRollbackMarker + update password hash.
  ///   9. On failure: deleteEnvelope, restore old envelope, show error.
  ///
  /// No vault files are re-encrypted — only the envelope changes.
  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final repo = CredentialRepository();
    final storage = SecureStorageService.instance;

    // 1. Verify current password.
    final saltBytes = await repo.loadSalt();
    final storedHash = await repo.loadPasswordHash();
    if (saltBytes == null || storedHash == null) {
      throw StateError('Vault is not set up.');
    }
    final iters = await repo.loadIterations() ?? 120000;
    final derived = await Isolate.run(
        () => _pbkdf2Worker((currentPassword, saltBytes, iters, 32)));
    final ok = await repo.verifyHash(derived, storedHash);
    if (!ok) throw ArgumentError('Incorrect current password.');

    // 2 + 3. Load DEK (envelope or legacy).
    final Uint8List dek;
    VaultKeyEnvelope? oldEnvelope;

    if (await repo.hasEnvelope()) {
      oldEnvelope = await repo.loadEnvelope();
      final oldKek = await DartCryptoEngine.deriveKek(
          currentPassword, oldEnvelope!.saltBytes, oldEnvelope.iterations);
      try {
        dek = DartCryptoEngine.unwrapDek(oldEnvelope.wrappedDekBytes,
            oldEnvelope.tagBytes, oldEnvelope.nonceBytes, oldKek);
      } finally {
        oldKek.fillRange(0, oldKek.length, 0);
      }
    } else {
      final masterKey = await repo.loadMasterKey();
      if (masterKey == null) throw StateError('No DEK found in storage.');
      dek = masterKey;
    }

    // 4. Derive new KEK with fresh salt.
    const newIters = 200000;
    final newSalt = _randomBytes(16);
    final newKek =
        await DartCryptoEngine.deriveKek(newPassword, newSalt, newIters);
    final wrapped = DartCryptoEngine.wrapDek(dek, newKek);

    // 5. Store rollback marker BEFORE new envelope (invariant).
    //    Storing a sentinel flag is sufficient — the old envelope still exists
    //    in secure storage until storeEnvelope overwrites it (atomic write).
    await repo.storeRollbackMarker(
        Uint8List.fromList(utf8.encode('rollback_in_progress')));

    // 6. Write new envelope.
    final newEnvelope = VaultKeyEnvelope(
      vaultVersion: 2,
      kdfAlgorithm: 'pbkdf2_sha256',
      kdfSalt: base64Encode(newSalt),
      kdfParams: {'iterations': newIters},
      wrappedDek: base64Encode(wrapped.ciphertext),
      wrappedDekNonce: base64Encode(wrapped.nonce),
      wrappedDekTag: base64Encode(wrapped.tag),
    );
    await repo.storeEnvelope(newEnvelope);

    // 7. Verify new envelope.
    final verKek =
        await DartCryptoEngine.deriveKek(newPassword, newSalt, newIters);
    final Uint8List dek2;
    try {
      dek2 = DartCryptoEngine.unwrapDek(
          wrapped.ciphertext, wrapped.tag, wrapped.nonce, verKek);
    } on AuthenticationFailure catch (e) {
      await repo.deleteEnvelope();
      // Restore old envelope if available.
      if (oldEnvelope != null) await repo.storeEnvelope(oldEnvelope);
      await repo.deleteRollbackMarker();
      throw StateError('Password change verification failed: $e');
    } finally {
      verKek.fillRange(0, verKek.length, 0);
    }

    if (!_bytesEqual(dek2, dek)) {
      await repo.deleteEnvelope();
      if (oldEnvelope != null) await repo.storeEnvelope(oldEnvelope);
      await repo.deleteRollbackMarker();
      throw StateError(
          'Password change verification: DEK round-trip mismatch.');
    }

    // 8. Success.
    newKek.fillRange(0, newKek.length, 0);
    await repo.deleteRollbackMarker();

    // Zero dek2 (verification copy) — it's always a distinct allocation from
    // unwrapDek or the dek2 comparison copy.
    dek2.fillRange(0, dek2.length, 0);
    // Zero dek only if it came from unwrapDek (envelope path). When it came
    // from loadMasterKey (legacy path), dek IS the stored masterKey and zeroing
    // it would corrupt other holders of that reference (CRASH-004).
    if (oldEnvelope != null) {
      dek.fillRange(0, dek.length, 0);
    }

    // Update the password hash so login verification still works.
    await storage.setPassword(newPassword);
    debugPrint('[AuthSession] Password changed successfully.');
  }

  /// Zero-fills [dek], unregisters the lifecycle observer, and clears [current].
  void lock() {
    _lockTimer?.cancel();
    _lockTimer = null;

    // Clear screenshot blocking flag before zeroing key material (fire-and-forget,
    // no-op on non-Android). .ignore() satisfies the unawaited-future lint.
    WindowSecurityService.setSecureFlag(false).ignore();

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
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Constant-time byte comparison used during migration verification.
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Generates [n] cryptographically random bytes.
  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
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
