# Design vs Tasks Verification Report

**Date:** 2026-10-13  
**Verified by:** Planning agent (pre-execution verification step)  
**Scope:** Phase 0 and Phase 1 tasks only

---

## 1. Optional service file existence check

| File | Exists? |
|------|---------|
| `lib/services/isolate_crypto_service.dart` | ✅ YES |
| `lib/services/isolate_encryption_service.dart` | ✅ YES |
| `lib/services/hardware_acceleration_service.dart` | ✅ YES |
| `lib/services/folder_crypto_service.dart` | ✅ YES |
| `lib/services/memory_management_service.dart` | ✅ YES |
| `lib/services/thermal_protection_service.dart` | ✅ YES |
| `lib/ui/auth/setup_screen.dart` | ✅ YES |
| `lib/ui/mobile/mobile_home_screen.dart` | ✅ YES |
| `lib/services/unified_import_service.dart` | ✅ YES |
| `lib/services/saf_zip_import_service.dart` | ✅ YES |
| `lib/app/auth_session.dart` | ❌ NO (new file — Task 1.1 creates it) |
| `lib/services/credential_repository.dart` | ❌ NO (new file — Task 1.1 creates it) |

All files referenced in Phase 0 and Phase 1 tasks either already exist or are explicitly marked as new files to create. No task references a non-existent file without the "new file" marker.

---

## 2. Phase 0 verification

Phase 0 is observation and benchmarking only. Confirmed: **no production code changes** in any Phase 0 task.

- Task 0.1: adds stopwatches to `secure_storage_service.dart` and `login_screen.dart` — logging only, no behaviour change. Safe.
- Task 0.2: adds stopwatches to `bulk_import_service.dart` and `import_export_service.dart` — logging only. Safe.
- Task 0.3: adds stopwatch to `import_export_service.dart` export path — logging only. Safe.
- Task 0.4: DevTools observation. No code change. Safe.

Output documents (`phase0_unlock.md`, `phase0_import.md`, `phase0_export.md`, `phase0_frames.md`) go under `docs/benchmarks/` — directory already exists.

**Phase 0 verdict: All 4 tasks safe to execute.**

---

## 3. Phase 1 task-by-task verification

### Task 1.1 — Move KDF off the UI isolate

**Files touched:**
- `lib/app/auth_session.dart` — NEW file (does not exist yet; creates it)
- `lib/services/credential_repository.dart` — NEW thin wrapper (does not exist yet)
- `lib/services/secure_storage_service.dart` — exists ✅
- `lib/ui/auth/login_screen.dart` — exists ✅

**Codebase findings:**
- `login_screen.dart` currently calls `AuthService.verifyPassword()` via `widget.auth` parameter, not `SecureStorageService` directly. Task 1.1 must also account for `auth_service.dart` (which wraps `SecureStorageService.verifyPassword()`).
- `SecureStorageService.verifyPassword()` calls `_pbkdf2Sha256()` synchronously on the calling isolate — confirmed in source. This is the UI freeze root cause.
- `_pbkdf2Sha256` uses PointyCastle PBKDF2 at 120,000 iterations — a heavy synchronous call, verified to be the cause of the KDF freeze.

**Design alignment:** Matches design §2.2 and §3.4. The design is clear: `AuthSession.unlock(password)` runs `Isolate.run(_pbkdf2Worker)`. `login_screen.dart` calls `AuthSession.unlock()` not `AuthService`.

**⚠️ Special care needed:** The current `login_screen.dart` takes an `AuthService` parameter injected by `auth_gate.dart`. Task 1.1 must also update `auth_gate.dart` (or the injection point) to pass `AuthSession` to `LoginScreen`, or adapt `AuthSession` to wrap the existing `AuthService` interface. If `auth_gate.dart` is not updated, the app will fail to build. **The task as written does not list `auth_gate.dart` as a file to touch — this is a gap. Add it to the task.**

**Vault health risk:** LOW if done carefully. The password verification outcome must remain identical — only the threading changes. The `Isolate.run()` wrapper preserves results. Existing `master_key_b64` in secure storage is untouched.

**Safe to execute:** YES, with the `auth_gate.dart` fix noted above.

---

### Task 1.2 — Remove artificial import delays

**Files touched:**
- `lib/services/bulk_import_service.dart` — exists ✅ (confirmed: has `Future.delayed(100ms)` between batches at line 86)
- `lib/services/memory_management_service.dart` — exists ✅ (confirmed: placeholder `_isMemoryPressureHigh` always returns false)
- `lib/services/enhanced_vault_repository.dart` — exists ✅

**Codebase findings:**
- `bulk_import_service.dart` has one `Future.delayed(const Duration(milliseconds: 100))` between batches (line 86). Removing it is safe — no file operations depend on the delay.
- `memory_management_service.dart` has fake GC: allocates nothing useful, `_isMemoryPressureLow()` always returns `true`. Confirmed placeholder.
- `enhanced_vault_repository.dart` uses `BatteryAwarenessService` (exists ✅) and `ThermalProtectionService` for delay decisions. The thermal service `shouldPause` path at line 201–204 **returns `false` silently** — this is also the Task 1.4 bug. Task 1.2 targets the artificial delays; Task 1.4 targets the skip-not-pause.
- `mobile_home_screen.dart` also has multiple `Future.delayed` calls (lines 1670, 1685, 1698, 1841, 2190, 2204). Task 1.2 as written does NOT list `mobile_home_screen.dart` as a file to touch. **Gap: if mobile import delays should be removed, this file needs to be added to the task.**

**Vault health risk:** LOW. Removing delays only speeds up the import; no crypto or DB logic changes.

**Safe to execute:** YES, with the note about `mobile_home_screen.dart` delays.

---

### Task 1.3 — Fix storage counter (remove O(n) scan)

**Files touched:**
- `lib/models/app_settings.dart` — exists ✅ (confirmed: currently has `maxStorageBytes` and `customTempFolderPath` only; fields `totalBytesUsed` and `lastReconciledAt` do NOT exist yet)
- `lib/services/vault_repository.dart` — exists ✅
- `lib/ui/home/home_screen.dart` — exists ✅
- `lib/ui/mobile/mobile_home_screen.dart` — exists ✅

**Codebase findings:**
- `app_settings.dart` confirmed: only 2 fields. Adding `totalBytesUsed` and `lastReconciledAt` requires running `isar_generator` (build_runner) to regenerate `app_settings.g.dart` — this is a **schema migration**. Isar handles additive migrations (new fields) automatically with default values, so existing data is safe.
- `vault_repository.dart` confirmed O(n) scan in `addMedia`: calls `_isar.vaultFiles.where().anyId().findAll()` to sum `byteSize`. This is the documented performance regression.
- `enhanced_vault_repository.dart` also calls the same O(n) scan in `_checkStorageLimits` — this file is NOT listed in Task 1.3. **Gap: the O(n) scan exists in two places.** `enhanced_vault_repository.dart` should also be updated or deprecated.

**⚠️ Special care needed:** After adding the `totalBytesUsed` field to Isar, the generated `.g.dart` file must be committed. The `reconcileStorageCounter()` method must run at first launch after the migration (when `lastReconciledAt == null`) to seed the counter from existing vault data. If it does not run or errors out, `totalBytesUsed` will show 0 and the storage limit check will be wrong, allowing imports past the set limit. This is the main vault-health risk for this task.

**Vault health risk:** MEDIUM. Isar schema change is additive and safe. The reconciliation seed must execute correctly on first run. **Recommend: test with a pre-populated vault before shipping.**

**Safe to execute:** YES, with explicit reconciliation test on upgrade.

---

### Task 1.4 — Fix thermal pause (stop skipping files)

**Files touched:**
- `lib/services/enhanced_vault_repository.dart` — exists ✅

**Codebase findings:**
- Confirmed bug at lines 201–204 in `_addFilesIndividually`:
  ```dart
  if (thermalConfig.shouldPause) {
    onStatusUpdate?.call('Device overheating - pausing to cool down...');
    await Future.delayed(Duration(milliseconds: thermalConfig.delayMs));
    return false; // Skip this file
  }
  ```
  The `return false` goes back to `_battery.processBatteryAware`, which treats a `false` result as a failed/skipped file. The file is never imported.
- Fix is minimal: change `return false` to `await Future.delayed(const Duration(seconds: 2)); continue;` style retry within the loop. The task description correctly describes this minimal fix.
- Note: `_battery.processBatteryAware` drives the loop — the fix may need to be implemented differently if the lambda cannot `continue` the outer loop. The task description says "retry; continue the loop after the pause" which is the right intent. Implementation must ensure the file IS retried after the pause, not just that the pause happens before the `return false`.

**Vault health risk:** MEDIUM on Android — this is a data integrity fix. Before the fix: files are silently dropped. After the fix: files are paused then retried. **Risk of regression is low if the retry logic is correct.** Risk of NOT fixing it is high: corrupted import batches.

**Safe to execute:** YES. This is a critical correctness fix. Test by simulating thermal stress on Android.

---

### Task 1.5 — Disable placeholder crypto services from call paths

**Files touched:**
- `lib/services/isolate_crypto_service.dart` — exists ✅
- `lib/services/isolate_encryption_service.dart` — exists ✅
- `lib/services/hardware_acceleration_service.dart` — exists ✅
- `lib/main.dart` — exists ✅ (confirmed: `HardwareAccelerationService.instance.initialize()` call at line 23)
- `lib/services/folder_crypto_service.dart` — exists ✅

**Codebase findings:**
- `main.dart` line 23: `await HardwareAccelerationService.instance.initialize()` — confirmed active caller. Also imports `memory_management_service.dart` and calls `MemoryManagementService.instance.optimizeMemorySettings()` at line 26. **Task 1.5 does not mention removing the `MemoryManagementService` call from `main.dart` — this should be added or addressed in Task 1.2.**
- `folder_crypto_service.dart` is used only in `enhanced_vault_repository.dart` (in `_addFilesAsContainer` and `_addFilesHybrid`). No other active callers found. Adding `@Deprecated` and removing it from the `container` and `hybrid` strategy paths is safe as long as the strategies are not triggered (they require certain file counts).
- `EnhancedVaultRepository` is instantiated in `mobile_home_screen.dart` (line 13 import, line 52 usage). Deprecating `FolderCryptoService` without deprecating `EnhancedVaultRepository` leaves the container/hybrid paths still callable but using a deprecated service. **Gap: consider also adding `@Deprecated` to `EnhancedVaultRepository` in this task, consistent with the design's quarantine table which lists it for Phase 2.**

**⚠️ Special care needed:** The `EncryptionStrategyService.analyzeEncryptionStrategy()` can choose `EncryptionStrategy.container` or `EncryptionStrategy.hybrid` based on file count. If `folder_crypto_service.dart` is deprecated/broken at call sites but `EnhancedVaultRepository` is still instantiated and still has those strategy paths active, an import of > 10 media files on Android would route to the container strategy and fail. The task says "MUST NOT be the default for any import" — the fix must ensure the strategy analysis never returns `container` or `hybrid` (or those paths throw immediately).

**Vault health risk:** HIGH if container/hybrid strategy paths are reachable after the fix. Must verify that all Android import paths route through the `individual` strategy only after this task.

**Safe to execute:** YES, but with explicit precaution: either remove or hard-fail the `container` and `hybrid` branches in `EnhancedVaultRepository._addMultipleMedia`, or ensure `EncryptionStrategyService` never returns those strategies. Do not leave a code path that calls deprecated `FolderCryptoService` silently.

---

### Task 1.6 — Desktop import: include all manga image types

**Files touched:**
- `lib/services/bulk_import_service.dart` — exists ✅ (confirmed: `_supportedImageExtensions` list exists)
- `lib/ui/home/home_screen.dart` — exists ✅

**Codebase findings:**
- `bulk_import_service.dart` `_supportedImageExtensions` already includes `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.webp`, `.svg`, `.apng`, `.avif`. **`.avif` and `.gif` are already present.** The main additions per the task are `.avif` (already there) and possibly `.mkv`, `.avi`, `.mp4` behind a `includeVideo` flag.
- The extension list in `bulk_import_service.dart` does NOT include `.mkv`, `.avi`, `.mp4`. This is the actual gap to fix.
- `mobile_home_screen.dart` import path uses `UnifiedImportService` and `EnhancedVaultRepository`, not `BulkImportService`. The extension fix in `BulkImportService` may not affect mobile imports. **Gap: if mobile file picking also filters by extension, the same fix is needed there.**

**Vault health risk:** LOW. Adding extensions to a list is additive. Existing imports are unaffected.

**Safe to execute:** YES.

---

### Task 1.7 — Add byte-accurate progress to import

**Files touched:**
- `lib/services/bulk_import_service.dart` — exists ✅
- `lib/ui/home/home_screen.dart` — exists ✅
- `lib/ui/mobile/mobile_home_screen.dart` — exists ✅

**Codebase findings:**
- `bulk_import_service.dart` currently reports progress as `filesProcessed/totalFiles` (count-based), with an artificial 100ms delay between batches.
- After Task 1.2 removes the delay, progress updates only happen per-file which is correct. Adding `totalBytes` upfront requires iterating file sizes before import starts — this adds a `File.length()` call per file, which is fast (metadata-only) but requires an extra loop pass before import begins.
- Design says: "after 1.2" in the dependency map — this ordering is correct. Task 1.7 must run after Task 1.2.

**Vault health risk:** LOW. Progress reporting is UI-only; no crypto or DB changes.

**Safe to execute:** YES. Dependency on Task 1.2 must be respected.

---

### Task 1.8 — Honest security claims in UI text and README

**Files touched:**
- `README.md` — exists ✅
- `lib/ui/auth/setup_screen.dart` — exists ✅
- `GUIDE.md` — exists ✅

**Codebase findings:**
- `setup_screen.dart` exists. No source read was done for this file, but it is confirmed present.
- Changes are text/documentation only. No crypto logic.

**Vault health risk:** NONE. Documentation changes cannot break vault operations.

**Safe to execute:** YES.

---

## 4. Design vs Tasks alignment check

| Concern | Finding |
|---------|---------|
| Design §7 quarantine table says `IsolateCryptoService`, `MemoryManagementService`, `ThermalProtectionService` etc. are Phase 1 | Tasks 1.2 and 1.5 cover these — aligned ✅ |
| Design §3.4 unlock sequence requires `AuthSession` new file | Task 1.1 creates it — aligned ✅ |
| Design §8.4 `StorageCounter` in `AppSettings` | Task 1.3 adds fields — aligned ✅ |
| Design says Phase 1 = "no crypto format change" | No Phase 1 task changes `FileCryptoService`, IV, blob format, or key storage — confirmed ✅ |
| Phase ordering: Phase 0 before Phase 1 | Design dependency map confirms parallel 0.x tasks then sequential 1.x — aligned ✅ |
| Task 1.3 needs `build_runner` for Isar codegen | Design confirms `isar_generator` regeneration is required — aligned ✅ |
| `auth_gate.dart` not listed in Task 1.1 | **Gap** — needs updating when `LoginScreen` API changes |
| `mobile_home_screen.dart` delays not listed in Task 1.2 | **Gap** — artificial delays exist there too |
| `enhanced_vault_repository.dart` O(n) scan not listed in Task 1.3 | **Gap** — scan exists in that file too |
| `MemoryManagementService` call in `main.dart` not in Task 1.5 | **Gap** — should be removed alongside `HardwareAccelerationService` |

---

## 5. Vault health check achievability after Phase 1

The six vault health criteria are:

1. **App launches and accepts v2.5.2 password** — Task 1.1 moves KDF to background isolate but does NOT change the password hash, salt, or master key stored in secure storage. Existing passwords remain valid. ✅ Achievable.

2. **Nested manga folder import completes (10+ pages)** — Tasks 1.2 and 1.4 improve import correctness. Task 1.3 improves storage tracking. None change the import crypto path. ✅ Achievable, and *better* after Phase 1.

3. **Imported pages browsable in natural sort order** — No Phase 1 task touches `sortOrder` logic or `listFiles()`. ✅ Achievable, unchanged.

4. **Opening a page decrypts and displays it** — No Phase 1 task changes `FileCryptoService`, `VaultOpenService`, or the decrypt path. ✅ Achievable, unchanged.

5. **(Windows) Export folder produces re-importable ZIP** — No Phase 1 task touches `import_export_service.dart` export path (only Task 0.3 adds a stopwatch). ✅ Achievable, unchanged.

6. **No crash, no ANR** — Task 1.1 eliminates the UI-freeze during KDF (was the primary ANR risk). Tasks 1.2/1.4 remove artificial delays and fix the file-skip bug. Task 1.5 removes fake services. Overall risk of ANR decreases after Phase 1. ✅ Achievable and improved.

**Conclusion: All vault health criteria are achievable after Phase 1.**

---

## 6. Summary

### Phase 1 tasks safe to execute (in dependency order):
1. **1.8** — documentation only, no risk, can run first
2. **1.1** — critical; safe with `auth_gate.dart` gap addressed  
3. **1.2** — safe; also address `mobile_home_screen.dart` delays  
4. **1.3** — safe; requires Isar build_runner step + reconciliation test on upgrade  
5. **1.4** — critical correctness fix; safe if retry logic is correct  
6. **1.5** — safe; precaution: hard-fail container/hybrid strategy branches  
7. **1.6** — safe, additive only  
8. **1.7** — safe; must run after 1.2 per dependency map  

### Tasks requiring special care:
- **Task 1.1** — `auth_gate.dart` must also be updated (not listed in task)
- **Task 1.3** — Isar schema migration: must run `build_runner`, and `reconcileStorageCounter()` must execute correctly at first launch after upgrade; test with pre-populated vault
- **Task 1.4** — Retry logic in `_addFilesIndividually` must actually retry the file, not just delay before returning false; verify against `_battery.processBatteryAware` lambda semantics
- **Task 1.5** — Container and hybrid strategy branches in `EnhancedVaultRepository` must be removed or hard-failed, not just deprecated at the `FolderCryptoService` level; risk of silent data loss if those branches remain callable

### Optional service files — all present in codebase:
All 9 queried optional services exist: `isolate_crypto_service`, `isolate_encryption_service`, `hardware_acceleration_service`, `folder_crypto_service`, `memory_management_service`, `thermal_protection_service`, `setup_screen`, `mobile_home_screen`, `unified_import_service`. None need to be created before Phase 1 tasks run.

### Files that do NOT yet exist (new files to create in Phase 1):
- `lib/app/auth_session.dart` — Task 1.1
- `lib/services/credential_repository.dart` — Task 1.1
- `docs/benchmarks/phase0_unlock.md` — Task 0.1 output
- `docs/benchmarks/phase0_import.md` — Task 0.2 output
- `docs/benchmarks/phase0_export.md` — Task 0.3 output
- `docs/benchmarks/phase0_frames.md` — Task 0.4 output
