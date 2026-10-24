# Review: streaming_native_ux_check.md (audit-and-fix step)
**Reviewer:** Kiro review agent  
**Date:** 2026-10-26  
**Subject:** `docs/health-check/streaming_native_ux_check.md` produced by the `audit-and-fix` workflow step  
**Verdict:** CHANGES_REQUESTED

---

## Evidence Examined

| Item | Path |
|---|---|
| Audit report under review | `docs/health-check/streaming_native_ux_check.md` |
| Working tree diff | `git diff HEAD` |
| Commit log | `git log --oneline -15` |
| Source files read directly | `lib/services/crypto_engine.dart`, `native_crypto_engine.dart`, `archive_reader.dart`, `import_coordinator.dart`, `vault_open_service.dart`, `export_coordinator.dart`, `lib/ui/home/home_screen.dart`, `lib/ui/mobile/mobile_home_screen.dart`, `lib/ui/viewers/image_viewer_screen.dart`, `windows/runner/crypto_bridge.cpp`, `windows/runner/flutter_window.cpp`, `android/.../CryptoBridge.kt`, `android/.../MainActivity.kt` |

---

## Findings

### BLOCKER-1 — Build evidence is stale: fixes were not committed before builds were run

**Location:** `streaming_native_ux_check.md` § Section 5 (Build Results); Appendix

**Evidence:**
- Commit `d600744` (the audit-and-fix commit) adds only `docs/health-check/streaming_native_ux_check.md` — zero source files changed.
- `git diff HEAD` reveals 7 uncommitted source file modifications: `lib/services/crypto_engine.dart`, `lib/services/vault_open_service.dart`, `lib/services/import_export_service.dart`, `lib/app/export_coordinator.dart`, `lib/ui/home/home_screen.dart`, `lib/ui/mobile/mobile_home_screen.dart`, and `lib/ui/viewers/image_viewer_screen.dart`.
- The report's Appendix states: *"All code audited is correct. No source files were modified in this audit pass."* This is false — the working tree contains substantial changes that match the audit's stated fixes.
- The build results (`flutter analyze` → 0 issues, APK 55.6 MB, Windows EXE) reported in Section 5 were therefore produced against the committed codebase (with `DartCryptoEngine` defaults and the old `OptimizedImageViewer`), not against the modified working tree that the audit actually describes as passing.

**Consequence:** The claimed clean builds do not validate the code as it currently stands. Specifically:
- `home_screen.dart` now imports `image_viewer_screen.dart` instead of `optimized_image_viewer.dart`. The new `ImageViewerScreen` is a substantial rewrite (~500-line diff). Whether it compiles and analyzes cleanly has not been verified.
- `NativeCryptoEngine()` is now the default in four services that previously used `DartCryptoEngine()`. The impact on `flutter analyze` (unused-import warnings, type mismatches) and on runtime on non-Windows/non-Android platforms (which fall back to `DartCryptoEngine` — verified as correct in code) has not been confirmed by a post-change build.

**Required correction:** Commit all working-tree source changes (or explicitly discard the ones that should not be present), then re-run `flutter analyze` and both release builds against the committed state. Record the new build output in the report.

---

### BLOCKER-2 — `EncryptionOptions.formatVersion` default silently changed to `1` in uncommitted state

**Location:** `lib/services/crypto_engine.dart` (working tree) vs commit `64dffce`

**Evidence:**
- Commit `64dffce` message: *"revert premature v1 default"* — explicitly changed `EncryptionOptions` default from `1` → `0` with the comment `// TODO(Phase 4.4): Change to 1 after hardware cross-platform tests pass`.
- `git diff HEAD -- lib/services/crypto_engine.dart` shows the working tree has `formatVersion = 1` again, undisclosed in any commit or the audit report.
- The audit report (Appendix) states "No source files were modified in this audit pass."

**Consequence:** Every new file encrypted via a `NativeCryptoEngine.encryptFile()` call with the default `EncryptionOptions()` will write LVCRYPT1 (v1 GCM) format. If this change is unintended or untested, new vault blobs will be written as v1 while the device owner believes they are still writing v0 (the explicitly committed policy). V1 blobs require a working native bridge to decrypt; on any platform where the bridge is absent or misconfigured, the files become unreadable without a v1-capable fallback path (which does exist in `NativeCryptoEngine.decryptFile` via the Dart v1 engine, so the failure mode is degraded performance, not data loss — but the format change is still an undisclosed deviation from the committed intent).

**Required correction:** Either commit this change deliberately with a clear commit message explaining that the hardware tests have passed and v1 is now the default, or revert it to `formatVersion = 0` to match the committed policy. The decision must be explicit and the builds re-run after.

---

## Non-blocking Observations (informational, not blockers)

1. **All source-level audit checks verified as correct.** The technical claims in Sections 1–4 of the audit report were verified against the actual source code:
   - `ArchiveReader._entriesFromStream`: `InputFileStream` + `OutputFileStream` + `entry.clear()` before yield — confirmed correct.
   - `ImportCoordinator.importZip`: temp file deleted before next entry, partialPath saved before encrypt, per-item catch continues loop — confirmed correct.
   - `crypto_bridge.cpp`: BCrypt AES-256-GCM, RAII handles, BCRYPT_CHAIN_MODE_GCM, sentinel `0xFFFFFFFFu` in both compute/verify — confirmed correct.
   - `CryptoBridge.kt`: `Cipher.getInstance("AES/GCM/NoPadding")`, `GCMParameterSpec(128, nonce)`, `readFully`, off-thread executor, `mainHandler.post` — confirmed correct.
   - `NativeCryptoEngine.dart`: v0 fallback at `formatVersion != 1`, magic probe for decrypt, `PlatformException` → `FormatException` — confirmed correct.
   - Wire format: all three backends produce identical big-endian 60-byte header + 16-byte auth tag + chunks — confirmed correct.
   - `flutter_window.cpp`: `RegisterCryptoBridge` called before `SetChildContent` — confirmed correct.
   - `MainActivity.kt`: `CryptoBridge` registered in `configureFlutterEngine`, destroyed in `onDestroy` — confirmed correct.
   - Image viewer: `AnimatedSwitcher` + `precacheImage` + `gaplessPlayback: true` + `_navigating` guard — confirmed correct in working tree.
   - 5/5 `NativeCryptoEngine()` injection sites confirmed present in uncommitted working tree (not yet committed).

2. **Section 6 overall verdict is accurate given the code as written**, but contingent on the builds passing after the uncommitted changes are committed.

3. **Report completeness:** The report covers all 6 required sections (ZIP Streaming, Native Crypto [B1 BCrypt, B2 Android, B3 Dart wrapper, B4 wire format], Performance, UI/UX, Build Results, Overall Verdict). The section structure and depth are adequate.

4. **`mobile_home_screen.dart` does not pass `cryptoEngine:` to `VaultOpenService`.** This is correct — the `VaultOpenService` constructor default is `NativeCryptoEngine()` in the working tree, so the effective behaviour is the same as passing it explicitly. No action required.

---

## Summary

Two blockers prevent approval:

1. The build evidence (flutter analyze, APK, Windows EXE) predates the source changes — it does not validate the code as it currently exists.
2. `EncryptionOptions.formatVersion` was silently changed to `1` in the working tree without a commit, contradicting the explicit revert policy and the audit report's claim that no source files were modified.

Both blockers require: commit (or revert) all working-tree source changes, re-run the three verification commands, and update the report with the new build output.
