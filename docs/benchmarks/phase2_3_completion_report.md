# Phase 2+3 Completion Report

**Date:** 2025-01-28  
**Commits:** FEAT-001 (678959c), FEAT-002 (7a0cd36), FEAT-003 (b394c36), FEAT-004 (this report)

---

## Phase 2 Tasks

### Task 2.1 ✅ — OperationJob and OperationJobItem Isar models
**Status:** Done  
**Key files:**
- `lib/models/operation_job.dart` — `OperationJob` collection: type, state, progress counters, timestamps, resume data
- `lib/models/operation_job_item.dart` — `OperationJobItem` collection: blobId, sourcePath, partialBlobPath, parentFolderId, failureReason
- `lib/models/operation_job.g.dart` — generated Isar schema (9 states × 4 types, schema id -4503300166057972159)
- `lib/models/operation_job_item.g.dart` — generated Isar schema (5 item states, index on jobId)
- `lib/db/isar_db.dart` — both schemas registered in `Isar.open()` schema list

### Task 2.2 ✅ — JobRepository
**Status:** Done  
**Key files:**
- `lib/services/job_repository.dart` — full CRUD: `createJob`, `createJobItem`, `markJobState`, `markJobItemState`, `findInterruptedJobs`, `findPendingItems`, `deleteJob`
- All queries use Isar-generated QueryBuilder (type-safe, index-backed)

### Task 2.3 ✅ — BlobStore + CryptoEngine interface
**Status:** Done  
**Key files:**
- `lib/services/blob_store.dart` — `createPartialPath`, `commitPartial` (atomic rename .partial→.bin), `deleteBlobIfExists`
- `lib/services/crypto_engine.dart` — `CryptoEngine` abstract interface: `encryptFile`, `decryptFile`, `deriveKey`; `EncryptResult` with ivBase64 + byteSize
- `lib/services/dart_crypto_engine.dart` — AES-256-CTR (SICStreamCipher/AESEngine) 64 KB chunks; PBKDF2 KDF in background isolate via `Isolate.run`

### Task 2.4 ✅ — AndroidThermalMonitor
**Status:** Done  
**Key files:**
- `lib/platform/android/android_thermal_monitor.dart` — polls `getThermalHeadroom` every 5 s; headroom thresholds: <0.15→severe, <0.30→moderate, <0.50→light; exposes `currentStatus` + `statusStream`
- `android/app/src/main/kotlin/com/yourname/local_vault/MainActivity.kt` — `thermal_protection` MethodChannel: `getThermalStatus` (API 29+ `PowerManager.currentThermalStatus`), `getThermalHeadroom` (API 29+ `PowerManager.getThermalHeadroom(5)`); graceful fallback to 0/1.0f on API < 29

### Task 2.5 ✅ — JobRunner
**Status:** Done  
**Key files:**
- `lib/app/job_runner.dart` — iterates `OperationJobItem` records in order; per-item: `BlobStore.createPartialPath` → `DartCryptoEngine.encryptFile` → `BlobStore.commitPartial` → `VaultRepository.addEncryptedBlobRecord` → `markJobItemState(completed)`; thermal pause on Android (≥ moderate → 5 s retry loop, never skips); `CancellationToken` checked between items; emits `JobProgress` stream

### Task 2.6 ✅ — ImportCoordinator
**Status:** Done  
**Key files:**
- `lib/app/import_coordinator.dart` — `importFolder(sourcePath, parentFolderId)` stream: enumerates supported files, creates `OperationJob` + items, delegates to `JobRunner`; `importZip(zipPath, destinationFolderId)` stream: uses `ArchiveReader.entries` for streaming extraction, encrypts inline, calls `repo.addEncryptedBlobRecord` (totalBytesUsed always updated — fixes B1); folder hierarchy resolved via `_ensureZipFolderStructure`

### Task 2.7 ✅ — ExportCoordinator (Windows only)
**Status:** Done  
**Key files:**
- `lib/app/export_coordinator.dart` — BFS to collect descendant folder ids; collects all files; one plaintext temp file on disk at a time (decrypt → add to ZIP → delete temp, inside finally block — fixes B3); relative entry paths built via folder path memo; `ArchiveWriter` opens/closes the ZIP
- `lib/services/archive_writer.dart` — thin wrapper around `ZipFileEncoder` from archive 3.6.1: `open()`, `addFile(entryName, filePath)`, `close()`; `assert(Platform.isWindows)` guard in `ExportCoordinator`

### Task 2.8 ✅ — Thin shell wiring
**Status:** Done  
**Key files:**
- `lib/ui/home/home_screen.dart` — `_importCoordinator` (`ImportCoordinator`) and `_exportCoordinator` (`ExportCoordinator`) wired at field declaration; folder import routes through `_importCoordinator.importFolder`; ZIP import shows `ArchiveReader`-backed dialog
- `lib/ui/mobile/mobile_home_screen.dart` — `_importCoordinator` field wired; Android ZIP import routes to `_MobileZipImportDialog` which calls `_importCoordinator.importZip`; folder import via `_EnhancedFolderImportDialog`

### Task 2.9 ✅ — Crash recovery on startup
**Status:** Done  
**Key files:**
- `lib/app/app.dart` — `_checkInterruptedJobs()` called in `addPostFrameCallback` after first frame; finds running/interrupted jobs, checks `.partial` blobs on disk; shows `_InterruptedJobsDialog` (count of partial files); user chooses "Discard & Clean Up": deletes partial blobs via `BlobStore.deleteBlobIfExists`, marks items skipped, marks jobs failed; SnackBar confirms cleanup

---

## Phase 3 Tasks

### Task 3.1 ✅ — ArchiveReader
**Status:** Done  
**Key files:**
- `lib/services/archive_reader.dart` — streaming via `InputFileStream` + `ZipDecoder().decodeBuffer(inputStream)` (archive v3.6.1 API); `entry.writeContent(OutputFileStream(tempPath))` streams to disk; `entry.clear()` frees memory per entry; `inputStream.closeSync()` in `finally` block; path safety: rejects `..`, `/`-prefix, Windows drive letters (`name[1] == ':'`); 2 GB size bomb check per entry; password-protected ZIPs fall back to `decodeBytes` (archive v3.x limitation noted in comment)

### Task 3.2 ✅ — ArchiveReader wired into ImportCoordinator
**Status:** Done  
**Key files:**
- `lib/app/import_coordinator.dart` `importZip()` — uses `ArchiveReader().entries(zipPath)` async* stream; each `ArchiveEntry` is encrypted inline (no full-archive RAM load); plaintext temp deleted with `File(e.tempPath).deleteSync()` before moving to next entry; `totalBytesUsed` updated via `repo.addEncryptedBlobRecord` (B1 fixed)

### Task 3.3 ✅ — Streaming export (ExportCoordinator)
**Status:** Done  
**Key files:**
- `lib/app/export_coordinator.dart` — one-file-at-a-time: decrypt to unique temp path → `ArchiveWriter.addFile` → delete temp in `finally`; no staging directory; peak plaintext on disk = one file at a time

---

## Bugs Fixed from Audit

### B1: totalBytesUsed not incremented on ZIP import
**Fixed in FEAT-003** (`importZip` in `ImportCoordinator`).  
Root cause: old `SafZipImportService` used `_isar.vaultFiles.put` directly without updating `AppSettings.totalBytesUsed`. New path goes through `repo.addEncryptedBlobRecord` which atomically increments the counter in the same Isar write transaction.

### B2: deleteFolderRecursive did not decrement totalBytesUsed
**Fixed in FEAT-001** (`vault_repository.dart`).  
`deleteFolderRecursive` now sums `vf.byteSize` for all collected files, clamps to 0, and writes back `settings.totalBytesUsed` in the same transaction that deletes the VaultFile and VaultFolder rows.

### B3: Export left multiple plaintext files on disk simultaneously
**Fixed in FEAT-002** (`ExportCoordinator`).  
Each file is decrypted to a uniquely-named temp path, added to the ZIP, then deleted in a `finally` block before the loop advances. At most one plaintext file exists on disk at any point.

### W1: SetupScreen ran PBKDF2 on UI thread
**Fixed in FEAT-001** (`auth_session.dart` + `dart_crypto_engine.dart`).  
`AuthSession.unlock` and `DartCryptoEngine.deriveKey` both delegate PBKDF2-HMAC-SHA256 to a background isolate via `Isolate.run`. The top-level `_pbkdf2Worker` function is reused in both (same algorithm parameters, same `utf8.encode` path).

---

## ArchiveReader Streaming Approach

The `archive` package follows a major API break between v3.x and v4.x:

| | archive v3.6.1 (this project) | archive v4.x |
|---|---|---|
| Streaming open | `InputFileStream(path)` + `ZipDecoder().decodeBuffer(inputStream)` | `InputFileStream` constructor was removed; streaming is via `ZipDecoder().decodeStream(...)` |
| Entry streaming | `entry.writeContent(OutputFileStream(path))` | `entry.writeContent(OutputFileStream(path))` (same) |
| Password ZIPs | `ZipDecoder().decodeBytes(bytes, password: pw)` | `ZipDecoder(password: pw).decodeStream(inputStream)` |

This project pins `archive: 3.6.1` in `pubspec.yaml`. The `ArchiveReader` uses the v3.6.1-correct API:

```dart
final inputStream = InputFileStream(zipPath);
try {
  final archive = ZipDecoder().decodeBuffer(inputStream);
  for (final entry in archive.files) {
    entry.writeContent(OutputFileStream(tempPath));
    entry.clear(); // free RAM immediately
  }
} finally {
  inputStream.closeSync(); // release OS file handle
}
```

Using `decodeBuffer(InputFileStream)` means the ZIP central directory is parsed from the file stream rather than from a `Uint8List` loaded entirely into RAM. This is the correct, memory-efficient approach for v3.6.1. Upgrading to v4.x would require replacing `InputFileStream` constructor calls and `decodeBuffer` with the v4 `decodeStream` API — but would not change observable behavior for the app.

---

## Build Results

| Step | Result | Key output |
|---|---|---|
| `dart run build_runner build --delete-conflicting-outputs` | **PASS** | 278 outputs, 574 actions — succeeded in 15.7 s |
| `flutter analyze` | **PASS** | No issues found (0 errors, 0 warnings) |
| `flutter build windows --release` | **PASS** | `build\windows\x64\runner\Release\local_vault.exe` (27.1 s) |
| `flutter build apk --release` | **PASS** | `build\app\outputs\flutter-apk\app-release.apk` (55.6 MB, 20 s) |

---

## App Flow Verification (Step 3 Audit Results)

All 7 flows traced through code — no CRASH or BROKEN issues found:

1. **Cold start** — `main.dart` → `IsarDb.open()` (reconciles counter if `lastReconciledAt` is null) → `VaultApp` initState → `addPostFrameCallback(_checkInterruptedJobs)` → `findInterruptedJobs()` → dialog if any interrupted → `AuthGate`. ✅
2. **First setup** — `AuthGate` → `SetupScreen` → password set via `SecureStorageService` (PBKDF2 on isolate via `AuthSession`) → push `HomeScreen` / `MobileHomeScreen`. ✅
3. **Desktop folder import** — `HomeScreen._importFolder` → `_importCoordinator.importFolder` → `JobRunner.run` → per-item: `BlobStore.createPartialPath` → `DartCryptoEngine.encryptFile` → `BlobStore.commitPartial` → `repo.addEncryptedBlobRecord` (increments `totalBytesUsed`) → `markJobItemState(completed)` → `JobProgress` stream → UI snackbar/dialog. ✅
4. **Desktop ZIP import** — `HomeScreen._importZip` → `_importCoordinator.importZip` → `ArchiveReader().entries(zipPath)` → per entry: encrypt → `repo.addEncryptedBlobRecord` → `totalBytesUsed` updated; plaintext temp deleted before next entry. ✅
5. **Mobile import** — `MobileHomeScreen._importZip` → if Android + path available: `_MobileZipImportDialog` → `_importCoordinator.importZip`; fallback: direct `_importCoordinator.importZip` stream consumed inline. ✅
6. **Windows export** — `HomeScreen` → `_exportCoordinator.exportFolder` → BFS collect folder ids → collect files → per file: `crypto.decryptBlobToFile` → `writer.addFile` → delete temp (in finally); `JobState.completed` on finish. ✅
7. **File delete** — `deleteFile` decrements `totalBytesUsed` in same Isar txn; `deleteFolderRecursive` accumulates `totalDeletedBytes` across entire subtree then decrements in same txn. Both clamped to 0. ✅

---

## ArchiveReader Security Checklist

| Check | Present |
|---|---|
| Uses `InputFileStream` + `ZipDecoder().decodeBuffer(inputStream)` | ✅ |
| `entry.writeContent(OutputFileStream(tempPath))` streams to disk | ✅ |
| `entry.clear()` after each entry | ✅ |
| `inputStream.closeSync()` in `finally` | ✅ |
| Path validation: `..` traversal | ✅ |
| Path validation: `/`-prefix (Unix absolute) | ✅ |
| Path validation: Windows drive letters (`C:`) | ✅ |
| Size bomb check (entry.size > 2 GB) | ✅ |

---

## What Comes Next: Phase 4

Phase 4 introduces a **versioned AEAD format** (AES-256-GCM chunked, 512 KB chunks with per-chunk auth tags and nonce derivation `base_nonce || chunk_index`). Key tasks:

- **4.1** Dart reference implementation of the v1 format in `DartCryptoEngine`; known-answer cross-platform test vectors
- **4.2** Windows native BCrypt/CNG backend via MethodChannel or FFI (`crypto_bridge.cpp`)
- **4.3** Android native `javax.crypto AES/GCM/NoPadding` backend via `CryptoBridge.kt` (activates ARMv8 Crypto Extensions on Cortex-A78)
- **4.4** Enable v1 as the default write format (legacy v0 blobs remain readable)

Phase 4 does **not** change the vault password/key storage — that is Phase 5 (password-wrapped DEK migration).
