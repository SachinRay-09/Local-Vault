# Phase 2+3 Final Audit — Local Vault

**Audit completed:** 2026-10  
**Build:** v2.5.2+6  
**Result:** ✅ All actionable issues resolved. Both Windows and Android release builds pass.

---

## 1. Issues Found and Fixed

### ISSUE-001 — AuthSession.dek stores wrong key ✅ Fixed (prior pass)

`AuthSession.unlock()` now loads the actual master key via `CredentialRepository.loadMasterKey()`
after verifying the password hash, storing the master key in the session — not the ephemeral
PBKDF2-derived bytes. This pre-empts a Phase 5 regression where DEK-wrapping would wrap the wrong
bytes.

**Files changed:** `lib/app/auth_session.dart`

---

### ISSUE-002 — Crash recovery: partial blobs never cleaned (ZIP path) ✅ Fixed (this pass)

**Root cause (ZIP-001):** `ImportCoordinator.importZip` called `blobStore.createPartialPath(blobId)`
but never persisted the path back to the item record. `partialBlobPath` stayed `null` for every
ZIP import item. After a crash, `app._checkInterruptedJobs` found the items but the
`if (partial != null)` guard short-circuited — no partial blobs were ever cleaned up.

**Fix:** Added `await jobRepo.saveItemPartialPath(item.id, partialPath)` immediately after the
`createPartialPath` call in `importZip`'s per-entry try block — mirroring the existing behaviour
in `JobRunner.run()`.

**Root cause (ZIP-002):** ZIP items were (and remain) created with `state = JobItemState.running`
since `importZip` owns its own inline encrypt-commit loop and intentionally bypasses `JobRunner`.
Added an explicit code comment documenting this design: `JobRunner.findPendingItems` only
processes `pending` items; ZIP items are never eligible for `JobRunner` processing. The crash-
recovery path in `app.dart` uses `findPendingOrRunningItems` so these items are still swept.

**Files changed:** `lib/app/import_coordinator.dart`  
**Previously fixed (prior pass):** `lib/services/job_repository.dart` (added `findPendingOrRunningItems`,
`saveItemPartialPath`), `lib/app/job_runner.dart` (calls `saveItemPartialPath`), `lib/app/app.dart`
(uses `findPendingOrRunningItems`).

---

### ISSUE-003 — Desktop ZIP import used legacy readAsBytes path ✅ Fixed (prior pass)

`home_screen._importZip()` now shows `_ZipImportProgressDialog` which drives
`_importCoordinator.importZip` (the streaming path). The legacy
`ImportExportService.importFromZip` call is gone from this code path.

**Files changed:** `lib/ui/home/home_screen.dart`

---

### ISSUE-007 — ArchiveReader false-positive path check and missing symlink guard ✅ Fixed (prior pass)

`_isUnsafePath` now requires a 3-character Windows drive-letter prefix (`C:\`) before flagging an
absolute path, eliminating the false positive on filenames like `2:30pm.jpg`. Symlink detection
(`mode & 0xF000 == 0xA000`) is present in both the streaming and in-memory entry loops.

**Files changed:** `lib/services/archive_reader.dart`

---

### ISSUE-011 — Mobile folder import bypassed ImportCoordinator ✅ Fixed (prior pass)

Mobile `_importFolder()` now collects file paths via the picker and passes them to
`_MobileFolderImportDialog`, which calls `_importCoordinator.importFileList`. That method creates
an `OperationJob` with `pending` items and delegates to `JobRunner`. Crash recovery now applies to
mobile folder imports.

**Files changed:** `lib/ui/mobile/mobile_home_screen.dart`, `lib/app/import_coordinator.dart`
(added `importFileList` method).

---

### ZIP-003 — `_ZipImportProgressDialog.password` silently defaulted to empty ✅ Fixed (this pass)

Changed `this.password = ''` to `required this.password` in the desktop
`_ZipImportProgressDialog` constructor. The call site in `_importZip()` already passes
`password: pw` explicitly, so behaviour is unchanged. Future call sites now get a compile-time
error rather than silently opening a password-protected ZIP with an empty key.

**Files changed:** `lib/ui/home/home_screen.dart`

---

## 2. Issues Confirmed Working (No Action Required)

| Issue | Status | Notes |
|-------|--------|-------|
| ISSUE-004 — DartCryptoEngine isolate safety | ✅ | Pure path-to-path ops, no captured state |
| ISSUE-005 — BlobStore path consistency | ✅ | All paths via `VaultPaths.ensureVaultBlobsDir()` |
| ISSUE-006 — JobRunner thermal guard | ✅ | `Platform.isAndroid` guard prevents NPE on Windows |
| ISSUE-008 — `addEncryptedBlobRecord` exists | ✅ | Updates `totalBytesUsed` in same transaction |
| ISSUE-009 — `deleteFile`/`deleteFolderRecursive` counters | ✅ | Clamp prevents underflow |
| ISSUE-010 — Isar schema version on cold start | ✅ | Additive schema changes; storage counter reconciled |
| ISSUE-012 — ExportCoordinator Windows-only guard | ✅ | `home_screen.dart` only loaded on Windows |
| ISSUE-013 — Auth flow end-to-end | ✅ | KDF runs off UI thread; setup order correct |
| ISSUE-014 — ArchiveReader streaming (unprotected ZIP) | ✅ | `InputFileStream` + `entry.clear()` |
| ISSUE-015 — Storage counter reconcile on startup | ✅ | `_reconcileStorageCounter` on first open |

---

## 3. Flows Verified Working

| Flow | Status |
|------|--------|
| Cold start → Isar.open → schema list (incl. OperationJob/OperationJobItem) | ✅ |
| Cold start → crash recovery (folder/file-list imports) | ✅ |
| Cold start → crash recovery (ZIP imports, partial blob cleanup) | ✅ Fixed |
| Login: AuthSession.unlock → KDF isolate → master key in session | ✅ |
| First setup: master key created before password hash | ✅ |
| Auth gate routing (Android→Mobile, Windows→Desktop) | ✅ |
| Desktop folder import via ImportCoordinator → JobRunner | ✅ |
| Desktop ZIP import via ImportCoordinator (streaming) | ✅ Fixed (ISSUE-003) |
| Mobile ZIP import via ImportCoordinator | ✅ |
| Mobile folder import via ImportCoordinator → JobRunner | ✅ Fixed (ISSUE-011) |
| JobRunner thermal guard on Windows (no NPE) | ✅ |
| Export: ExportCoordinator.exportFolder (Windows) | ✅ |
| File view/decrypt: VaultOpenService.decryptToCachedTempFile | ✅ |
| deleteFile / deleteFolderRecursive counter decrements | ✅ |
| BlobStore partial → commit path consistency | ✅ |
| ArchiveReader streaming (unprotected ZIP) | ✅ |
| ArchiveReader zip-slip + symlink protection | ✅ Fixed (ISSUE-007) |
| AndroidThermalMonitor on Windows (no platform channel) | ✅ |

---

## 4. Build Verification

| Step | Result |
|------|--------|
| `flutter analyze` | ✅ No issues found |
| `flutter build windows --release` | ✅ `local_vault.exe` built successfully |
| `flutter build apk --release` | ✅ `app-release.apk` (55.6 MB) built successfully |

No `dart run build_runner build` run was needed — no model/schema fields were changed in this pass.

---

## 5. Issues NOT Fixed (with Justification)

### ISSUE-001 Phase 5 prerequisite methods (`storeEnvelope`, `loadEnvelope`, `wrapDek`, etc.)

These methods (`CredentialRepository.storeEnvelope`, `DartCryptoEngine.wrapDek`, `VaultFile.formatVersion`)
are Phase 5 scope. Adding them now would be out-of-scope feature work and would require Isar schema
migrations. They are documented in audit_plan.md §5 as Phase 5 dependencies.

### FileTagSchema / FileTagAssignmentSchema not registered

The `FileTag` and `FileTagAssignment` models have `@collection` annotations but are not in
`Isar.open()`. This is not a crash risk today — no code queries `isar.fileTags`. Adding the
schemas requires a schema migration run. This is Phase 5/6 tag search scope.

### Concurrency policy (2 workers on Windows)

Design §2.2 specifies 2 concurrent workers on Windows. `JobRunner` currently runs sequentially
(1 worker). This is a performance gap, not a crash, and was deliberately deferred per audit_plan.md §6.
