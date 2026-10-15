# Phase 4 Completion Report

## Status: Review findings resolved — pending hardware cross-platform tests

---

## Blocking Fix 1 — Nonce reuse: sentinel 0xFFFFFFFF for header tag ✅

**Finding:** All three backends (`_computeHeaderTag` in Dart, `compute_header_tag`
in C++, `computeHeaderTag` in Kotlin) previously called `buildChunkNonce(baseNonce, 0)`,
producing the same 12-byte nonce as data chunk 0. AES-GCM requires strict
(key, nonce) uniqueness across all GCM operations under the same key.

**Fix applied:** All three backends now use sentinel index `0xFFFFFFFF` for the
header tag nonce computation:

| Backend | Change |
|---------|--------|
| Dart (`dart_crypto_engine.dart`) | `_chunkNonce(baseNonce, 0xFFFFFFFF)` in both `_computeHeaderTag` and `_decryptFileV1` |
| C++ (`crypto_bridge.cpp`) | `build_chunk_nonce(base_nonce, 0xFFFFFFFFu, ...)` in both `compute_header_tag` and `verify_header_tag` |
| Kotlin (`CryptoBridge.kt`) | `buildChunkNonce(baseNonce, 0xFFFFFFFF.toInt())` in both `computeHeaderTag` and the decrypt verify block |

**Wire format implication:** The header auth tag nonce changes from
`base_nonce||0x00000000` to `base_nonce||0xFFFFFFFF`. Since v1 was not yet the
default and no real user data uses v1 blobs, this finalizes the v1 wire format
without affecting any existing data.

**Test coverage:** Test 12 in `test/crypto/aead_vectors_test.dart` verifies that
bytes [8..11] of the header-tag nonce equal `0xFF 0xFF 0xFF 0xFF` and that
bytes [8..11] of the chunk-0 nonce equal `0x00 0x00 0x00 0x00`, and confirms
a successful decrypt round-trip after the fix.

---

## Blocking Fix 2 — v1 default reverted to 0 pending hardware tests ✅

**Finding:** `EncryptionOptions.formatVersion` defaulted to `1` prematurely.
The plan required this change only after confirmed Dart↔BCrypt and
Dart↔javax.crypto cross-platform hardware round-trips, which have not yet run.

**Fix applied:**
- `EncryptionOptions({this.formatVersion = 0})` — default reverted to v0 (safe,
  existing behaviour)
- `EncryptResult({..., this.formatVersion = 0})` — default aligned with
  encryption default
- Both now carry the comment:
  `// TODO(Phase 4.4): Change to 1 after hardware cross-platform tests pass on GT Book + Z9x`

**Impact:** New encryptions continue to use the proven AES-256-CTR v0 path
until hardware tests confirm cross-platform interop. Callers that explicitly
pass `EncryptionOptions(formatVersion: 1)` still exercise the full v1 code path.

---

## Minor Fix 3 — Test 12: nonce sentinel correctness ✅

Added Test 12 to `test/crypto/aead_vectors_test.dart`:

- Encrypts a 1-byte file using v1 format
- Reads the on-disk blob and extracts `base_nonce` from header offset [40..51]
- Reconstructs both nonces (header sentinel 0xFFFFFFFF and chunk-0 counter 0x00000000)
- Asserts the two nonces differ and each carries the expected counter bytes
- Confirms decrypt succeeds with the corrected implementation

All 12 tests pass: `flutter test test/crypto/aead_vectors_test.dart`.

---

## Minor Fix 4 — Android doFinal zero-ciphertext path ✅

Added a detailed comment block in `CryptoBridge.kt` above `computeHeaderTag`:

- Documents the JCA GCM contract: `doFinal()` on ENCRYPT_MODE with empty input
  returns 0 bytes of ciphertext + 16-byte appended tag
- Documents that on DECRYPT_MODE, passing a 16-byte buffer treats the last
  `tagLen` bytes as the auth tag and 0 bytes as ciphertext — correct per spec
- States this was verified to match the Dart reference implementation
  (`GCMBlockCipher.process` on empty input)
- Carries a TODO to add an instrumented Android test when `androidTest/`
  infrastructure is configured

---

## Remaining Gate Before v1 Becomes Default

The v1 format is fully implemented and tested via the Dart reference
implementation (`DartCryptoEngine`). The remaining gate before
`EncryptionOptions.formatVersion` defaults to `1` is:

1. **Hardware cross-platform test — Windows:** Encrypt a file with
   `DartCryptoEngine` (v1), decrypt with `NativeCryptoEngine` (BCrypt) on the
   target GT Book device, and vice-versa. Confirm identical plaintext.

2. **Hardware cross-platform test — Android:** Encrypt with `DartCryptoEngine`
   (v1), decrypt with `NativeCryptoEngine` (javax.crypto) on the Z9x device,
   and vice-versa. Confirm identical plaintext.

Once both round-trips pass, change `formatVersion = 0` → `formatVersion = 1`
in both `EncryptionOptions` and `EncryptResult` defaults in `crypto_engine.dart`
and remove the TODO comment.

---

## Build Verification

| Target | Result |
|--------|--------|
| `flutter analyze` | ✅ No issues |
| `flutter test test/crypto/aead_vectors_test.dart` | ✅ 12/12 passed |
| `flutter build windows --release` | ✅ local_vault.exe |
| `flutter build apk --release` | ✅ app-release.apk (55.6 MB) |
