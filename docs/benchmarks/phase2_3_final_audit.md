# Phase 2 + 3 Final Audit Report

**Date:** 2026-10  
**Auditor:** Coding sub-agent — Phase 2+3 audit pass  
**Build:** v2.5.2+6  
**Audit input:** `.agents/tasks/audit_plan.md`

---

## Summary

5 actionable issues from the audit plan were fixed. All 15 flows confirmed in the audit plan were
re-verified. Both Windows and Android builds pass clean after the fixes.

---

## Issues Fixed

### ISSUE-001 — AuthSession.dek stores wrong key ✅ FIXED

**File:** `lib/app/auth_session.dart`

**Root cause:** `AuthSession.unlock()` was storing the PBKDF2-derived key (used only for password
verification) as `session.dek` instead of the actual random master key from secure storage.

**Fix:** After a successful password verify, load the master key via
`CredentialRepository.loadMasterKey()` and store that in the session. The PBKDF2 key is no
longer retained after the hash comparison.

**Impact:** Zero behaviour change in Phase 2/3 (no code path reads `authSession.dek`). This
pre-empts a Phase 5 regression where DEK wrapping would have used the wrong bytes.

---

### ISSUE-002 — Crash recovery never finds partial blobs ✅ FIXED

**Files:**
- `lib/services/job_repository.dart`
- `lib/app/job_runner.dart`
- `lib/app/app.dart`

**Root cause (Bug 2a):** `OperationJobItem.partialBlobPath` was never written by `JobRunner` —
it stayed `null` so the crash-recovery check `if (partial != null)` always skipped every item.

**Root cause (Bug 2b):** `app.dart._checkInterruptedJobs` called `findPendingItems` which only
queries state = `pending`, missing any items that had already been marked `running`.

**Fixes:**
1. Added `JobRepository.saveItemPartialPath(int id, String path)` — persists the partial path in
   the Isar row.
2. Added `JobRepository.findPendingOrRunningItems(int jobId)` — returns items with state `pending`
   OR `running`.
3. `JobRunner.run()` now calls `jobRepo.saveItemPartialPath(item.id, partialPath)` immediately
   after `blobStore.createPartialPath()` so the path is persisted before encryption starts.
4. `app.dart._checkInterruptedJobs` now calls `findPendingOrRunningItems` instead of
   `findPendingItems`.

**Impact:** Crash recovery now correctly identifies partial blobs and shows the real count in the
dialog. Clean-up deletes all partial blobs on disk.

---

### ISSUE-003 — Desktop ZIP import uses legacy readAsBytes path ✅ FIXED

**File:** `lib/ui/home/home_screen.dart`

**Root cause:** `_importZip()` on desktop called `_importExport.importFromZip` (loads the whole
ZIP into RAM via `readAsBytes`). `ImportCoordinator.importZip` (streaming) was wired on mobile
only.

**Fix:** Replaced `_importZip()` body to show a new `_ZipImportProgressDialog` that drives
`_importCoordinator.importZip`. The user-visible flow is identical (same password prompt, same
recommendation dialog). The legacy `importFromZip` call is removed.

**Impact:** Large ZIPs on Windows no longer risk OOM. Storage counter (`totalBytesUsed`) is now
always updated correctly because all imports go through
`VaultRepository.addEncryptedBlobRecord`.

---

### ISSUE-007 — ArchiveReader false-positive path check and missing symlink guard ✅ FIXED

**File:** `lib/services/archive_reader.dart`

**Root cause (false-positive):** `_isUnsafePath` flagged any name where `name[1] == ':'` — this
incorrectly rejected valid filenames like `2:30pm.jpg`.

**Root cause (symlink):** Symbolic-link entries were not detected; a ZIP with a symlink pointing
to a relative path (no `..`) would pass the safety check.

**Fixes:**
1. Changed the Windows path check to require `name[1] == ':' && (name[2] == '\\' || name[2] == '/')` —
   properly matches drive-letter paths like `C:\` while leaving filenames like `2:30pm.jpg` alone.
2. Added symlink detection in both `_entriesFromStream` and `_entriesFromBytes` loops using Unix
   mode bit `0xA000` (symlink type in archive 3.x). Symlink entries yield `ArchiveEntrySkipped`
   with reason `'symbolic link'`.

**Impact:** Previously-rejected filenames like `2:30pm.jpg` are now accepted. ZIP symlink entries
are silently skipped rather than extracted.

---

### ISSUE-011 — Mobile folder import bypasses ImportCoordinator ✅ FIXED

**Files:**
- `lib/app/import_coordinator.dart` — new `importFileList()` method added
- `lib/ui/mobile/mobile_home_screen.dart` — new `_MobileFolderImportDialog`; `_importFolder()`
  wired to it

**Root cause:** Mobile `_importFolder()` used `_EnhancedFolderImportDialog` which called
`EnhancedVaultRepository.addMultipleMedia` — the legacy path with fake thermal service. No
`OperationJob` record was created and crash recovery did not apply.

**Fix:** Added `ImportCoordinator.importFileList(List<String> filePaths, ...)` that:
- Creates an `OperationJob` and one `OperationJobItem` per file
- Delegates to `JobRunner` for encryption (same path as folder/ZIP imports)
- Creates a single root vault folder named from the first file's parent directory

`_importFolder()` now collects file paths from the picker and shows `_MobileFolderImportDialog`
which drives `_importCoordinator.importFileList`. The user-visible flow is identical (same
instruction dialog, same multi-file picker).

**Impact:** Mobile folder imports now go through the job engine. Crash recovery applies. The
`totalBytesUsed` counter is always updated. The fake thermal skip path is no longer used for
this flow.

---

## Issues Confirmed Working (No Change Needed)

| Issue | Status | Notes |
|-------|--------|-------|
| ISSUE-004 — DartCryptoEngine isolate safety | ✅ No issue | No instance state captured in closures |
| ISSUE-005 — BlobStore path consistency | ✅ No issue | All services use VaultPaths.ensureVaultBlobsDir |
| ISSUE-006 — JobRunner thermal guard | ✅ No issue | Platform.isAndroid guard present; null-safe on Windows |
| ISSUE-008 — addEncryptedBlobRecord exists | ✅ No issue | Method in VaultRepository, updates counter |
| ISSUE-009 — deleteFile/deleteFolderRecursive counter | ✅ No issue | Both decrement with clamp |
| ISSUE-010 — Isar schema version | ✅ No issue | OperationJob + OperationJobItem in schema list |
| ISSUE-012 — ExportCoordinator Windows guard | ✅ No issue | Only loaded on Windows via auth routing |
| ISSUE-013 — Auth flow end-to-end | ✅ No issue | Login, setup, routing all correct |
| ISSUE-014 — ArchiveReader streaming | ✅ No issue | InputFileStream + entry.writeContent path |
| ISSUE-015 — Storage counter reconcile | ✅ No issue | _reconcileStorageCounter on cold start |
| ISSUE-001 (schema) — Isar schema registration | ✅ No issue | Both generated schemas in Isar.open() |

---

## Flows Verified After Fixes

| Flow | Status | Notes |
|------|--------|-------|
| Cold start → Isar.open → schema list | ✅ | OperationJob + OperationJobItem registered |
| Cold start → crash recovery | ✅ FIXED | Now finds running items with partial blobs |
| Login: AuthSession.unlock → master key in dek | ✅ FIXED | Master key stored, not PBKDF2 key |
| Login: KDF in background isolate | ✅ | Unchanged |
| First setup | ✅ | Master key created before hash |
| Auth gate routing | ✅ | Android→Mobile, Windows→Desktop |
| Desktop folder import via ImportCoordinator | ✅ | Unchanged |
| Desktop ZIP import via ImportCoordinator | ✅ FIXED | Streaming path, no OOM risk |
| Mobile ZIP import via ImportCoordinator | ✅ | Unchanged |
| Mobile folder import via ImportCoordinator | ✅ FIXED | Now uses importFileList + JobRunner |
| JobRunner partial path persisted | ✅ FIXED | saveItemPartialPath called before encrypt |
| JobRunner thermal guard (non-Android) | ✅ | Unchanged |
| Export: ExportCoordinator.exportFolder | ✅ | Unchanged |
| File view/decrypt | ✅ | Unchanged |
| deleteFile / deleteFolderRecursive counter | ✅ | Unchanged |
| BlobStore path consistency | ✅ | Unchanged |
| ArchiveReader streaming (unprotected ZIP) | ✅ | Unchanged |
| ArchiveReader zip-slip protection | ✅ FIXED | Symlinks excluded; false-positive removed |
| AndroidThermalMonitor on Windows | ✅ | Unchanged |

---

## Build Verification

| Build | Result |
|-------|--------|
| `flutter analyze` | ✅ 0 issues |
| `flutter build windows --release` | ✅ `local_vault.exe` built |
| `flutter build apk --release` | ✅ `app-release.apk` (55.6 MB) |

No `build_runner` run was needed — no Isar model fields were changed.

---

## Issues NOT Fixed

None — all actionable Phase 2/3 issues have been addressed.

### Phase 5 pre-requisite items (out of scope for this audit)

The following are tracked in the audit plan (Section 5) but are Phase 4/5 work, not Phase 2/3
bugs:

- `CredentialRepository.storeEnvelope / loadEnvelope / hasEnvelope` — Phase 5 Task 5.1
- `DartCryptoEngine.deriveKek / wrapDek / unwrapDek` — Phase 5 Task 5.2
- `VaultFile.formatVersion` field — Phase 4 Task 4.1
- `NativeCryptoEngine` (Windows + Android) — Phase 4 Tasks 4.2/4.3
- `FileTagSchema / FileTagAssignmentSchema` not in Isar.open — Phase 5/6 (not a current crash)
