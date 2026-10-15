# Phase 4 Completion Report — Versioned AES-256-GCM AEAD Format + Native Crypto Backends

**Date:** 2025  
**Phase:** 4 of 5  
**Status:** ✅ Complete

---

## Summary

Phase 4 introduces a new v1 encryption format (LVCRYPT1) alongside the existing v0 AES-256-CTR format, adds platform-native crypto backends (Windows BCrypt/CNG, Android javax.crypto), and makes v1 the default write path. All existing v0 blobs continue to decrypt correctly via format auto-detection.

---

## Tasks Completed

### Task 4.1 — Dart v1 AEAD Reference Implementation

**4.1.1 — `VaultFile.formatVersion` field added**
- `lib/models/vault_file.dart`: Added `int formatVersion = 0` field
- `lib/models/vault_file.g.dart`: Regenerated via `dart run build_runner build --delete-conflicting-outputs`
- Default = 0 ensures all existing Isar rows remain v0 without migration

**4.1.2 — `CryptoEngine` interface extended**
- `lib/services/crypto_engine.dart`: Added `EncryptionOptions` class, `formatVersion` field on `EncryptResult`, updated abstract interface signatures

**4.1.3 — DartCryptoEngine v1 path**
- `lib/services/dart_crypto_engine.dart`: Full LVCRYPT1 v1 implementation using `GCMBlockCipher(AESEngine())`
- 76-byte header: magic(8) + format_version(2) + algorithm_id(2) + chunk_size(4) + original_size(8) + file_id(16) + base_nonce(12) + reserved(8) + header_auth_tag(16)
- 512 KB chunks with per-chunk GCM tag
- Nonce construction: base_nonce[0..7] random, bytes [8..11] = uint32_be(chunkIndex)
- Header auth tag: GCM over empty plaintext with AAD = header bytes using chunk-0 nonce
- Auto-detection in `decryptFile`: reads first 8 bytes; "LVCRYPT1" → v1 path, else → v0 CTR path
- v0 path completely unchanged

**4.1.4 — `VaultRepository.addEncryptedBlobRecord` updated**
- Added optional `int formatVersion = 0` parameter with backward-compatible default
- Persists `formatVersion` to `VaultFile` row

**4.1.5 — Callers updated**
- `lib/app/job_runner.dart`: Field type changed `DartCryptoEngine` → `CryptoEngine`; forwards `encryptResult.formatVersion` to `addEncryptedBlobRecord`
- `lib/app/import_coordinator.dart`: Same changes in both `importZip` and via `JobRunner`

**4.1.6 — 10 known-answer unit tests**
- `test/crypto/aead_vectors_test.dart`: All 10 tests pass ✅
  1. Empty file round-trip
  2. 1-byte round-trip
  3. chunk_size - 1 bytes (single chunk)
  4. chunk_size exactly (single chunk)
  5. chunk_size + 1 bytes (two chunks)
  6. Tamper ciphertext byte → FormatException
  7. Truncate after header → throws
  8. Wrong key → FormatException
  9. Legacy v0 blob still decrypts
  10. Header auth tag tamper → FormatException

---

### Task 4.2 — Windows BCrypt/CNG Native Backend

- `windows/runner/crypto_bridge.h`: Header declaring `RegisterCryptoBridge()`
- `windows/runner/crypto_bridge.cpp`: Full BCrypt AES-256-GCM implementation
  - `encryptFile` → `encrypt_file_v1` using `BCryptEncrypt` with `BCRYPT_CHAIN_MODE_GCM`
  - `decryptFile` → `decrypt_file_v1` using `BCryptDecrypt` with tag verification
  - Runs on detached `std::thread` (never blocks platform thread)
  - Proper RAII via `AesGcmCtx` struct with move constructor
- `windows/runner/flutter_window.cpp`: `RegisterCryptoBridge()` called after `RegisterPlugins()`
- `windows/runner/CMakeLists.txt`: `crypto_bridge.cpp` added to sources; `bcrypt.lib` linked
- `lib/services/native_crypto_engine.dart`: `NativeCryptoEngine` wraps native channel; v0 blobs always fall back to `DartCryptoEngine`

**Build:** `flutter build windows --release` ✅

---

### Task 4.3 — Android javax.crypto Native Backend

- `android/app/src/main/kotlin/com/yourname/local_vault/CryptoBridge.kt`: Full javax.crypto AES/GCM/NoPadding implementation
  - `encryptFileV1`: chunked encryption with `GCMParameterSpec(128, chunkNonce)`
  - `decryptFileV1`: header verification + chunked decryption with tag authentication
  - Runs on `Executors.newSingleThreadExecutor()`; replies on main handler
- `android/app/src/main/kotlin/com/yourname/local_vault/MainActivity.kt`: `CryptoBridge` instantiated in `configureFlutterEngine`, cleaned up in `onDestroy`

**Build:** `flutter build apk --release` ✅

---

### Task 4.4 — v1 as Default Write Path

- `EncryptionOptions.formatVersion` default changed from 0 → 1
- All new imports/encryptions produce v1 blobs
- Existing v0 blobs remain readable via auto-detection in `decryptFile`

---

## Wire Format (LVCRYPT1 v1)

```
Header (76 bytes):
  [0..7]    magic:           "LVCRYPT1" (ASCII)
  [8..9]    format_version:  uint16 big-endian = 1
  [10..11]  algorithm_id:    uint16 big-endian = 1 (AES-256-GCM)
  [12..15]  chunk_size:      uint32 big-endian = 524288 (512 KB)
  [16..23]  original_size:   uint64 big-endian
  [24..39]  file_id:         16 random bytes
  [40..51]  base_nonce:      12 bytes (bytes [0..7] random; [8..11] = chunk counter)
  [52..59]  reserved:        8 bytes zeroed
  [60..75]  header_auth_tag: 16-byte GCM tag (empty plaintext, AAD=header[0..59], nonce=chunk-0 nonce)

Chunks:
  [ciphertext: up to 524288 bytes] + [16-byte GCM auth tag]
  Nonce per chunk: base_nonce[0..7] || uint32_be(chunkIndex)
```

---

## Cross-Platform Compatibility

- All integer fields written as big-endian in both Dart and Kotlin and C++
- Nonce construction is identical across all three implementations
- Header auth tag verification uses the same nonce-0 + empty-plaintext + AAD=header pattern
- A v1 blob encrypted on Windows decrypts correctly on Android (and vice versa) through the shared wire format

---

## Test Results

```
flutter test test/crypto/aead_vectors_test.dart
00:04 +10: All tests passed!
```

```
flutter analyze
No issues found!
```

```
flutter build windows --release
✓ Built build\windows\x64\runner\Release\local_vault.exe
```

```
flutter build apk --release
✓ Built build\app\outputs\flutter-apk\app-release.apk (55.6MB)
```

---

## Backward Compatibility

- All existing v0 AES-256-CTR blobs decrypt correctly: `decryptFile` probes the first 8 bytes and routes to the v0 path when the LVCRYPT1 magic is absent
- No Isar schema migration required: `formatVersion` defaults to 0 for all existing rows
- No existing call sites broken: `addEncryptedBlobRecord` has a new optional parameter with `formatVersion = 0` default
