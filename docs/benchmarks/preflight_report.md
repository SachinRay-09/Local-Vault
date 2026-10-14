# Pre-flight Report

**Date:** 2026-10-13  
**Baseline:** v2.5.2+6 · Flutter/Dart 3.2+ · Isar 3.1.0+1  
**Workspace:** `p:\personalVault\local_vault`

---

## 1. `flutter pub get` result

**Exit code:** 0 (SUCCESS)

Dependencies resolved and downloaded without errors. 9 packages updated (transitive), 118 packages have newer versions available but are held back by existing version constraints — this is expected and normal at this stage.

---

## 2. Required package audit

All required packages are present in `pubspec.yaml`:

| Package | Location | Version constraint | Resolved version | Status |
|---|---|---|---|---|
| `isar` | dependencies | `^3.1.0+1` | 3.x | ✅ Present |
| `isar_flutter_libs` | dependencies | `^3.1.0+1` | 3.x | ✅ Present |
| `isar_generator` | dev_dependencies | `^3.1.0+1` | 3.x | ✅ Present |
| `build_runner` | dev_dependencies | `^2.4.9` | 2.4.9 | ✅ Present |
| `path_provider` | dependencies | `^2.1.1` | 2.1.4 | ✅ Present |
| `flutter_secure_storage` | dependencies | `^8.0.0` | 8.1.0 | ✅ Present |
| `encrypt` | dependencies | `^5.0.1` | 5.x | ✅ Present |
| `pointycastle` | dependencies | `^3.7.3` | 3.9.1 | ✅ Present |
| `crypto` | dependencies | `^3.0.3` | 3.0.3 | ✅ Present |
| `path` | dependencies | `^1.8.3` | 1.9.0 | ✅ Present |
| `archive` | dependencies | `^3.4.9` | 3.6.1 | ✅ Present |

**Missing packages:** None.

---

## 3. Archive version note

**Resolved version:** `archive 3.6.1`  
**Latest available:** 4.5.2

> ⚠️ **Do NOT upgrade `archive` to v4.x yet.**  
> Phase 3 (Task 3.1 — ArchiveReader) will perform this upgrade as part of the streaming ZIP migration. The v4 API introduces `ZipDecoder().decodeStream(InputFileStream(path))` with lazy entry references and `entry.writeContent(OutputFileStream(path))` for zero-copy streaming — these APIs do not exist in v3.x. The upgrade will be done in-tandem with implementing `ArchiveReader` so both the new API usage and the dependency bump land together in one tested commit.

---

## 4. Pre-existing analyzer findings

**`flutter analyze` exit code:** 1  
**Total issues found:** 3 (all `info` severity — no `error` or `warning` level issues)

All 3 are the same deprecation notice:

| # | Severity | Rule | File | Line |
|---|---|---|---|---|
| 1 | info | `deprecated_member_use` | `lib/ui/home/home_screen.dart` | 1697 |
| 2 | info | `deprecated_member_use` | `lib/ui/mobile/mobile_home_screen.dart` | 1241 |
| 3 | info | `lib/ui/pickers/folder_picker_screen.dart` | 64 | — |

**Detail:** `onPopInvoked` is deprecated after Flutter v3.22.0-12.0.pre; the replacement is `onPopInvokedWithResult`. These are pre-existing issues, not introduced by this workflow.

**Errors (blocking):** 0  
**Warnings:** 0  
**Info (pre-existing, non-blocking):** 3

> These 3 infos will be addressed as part of the shell extraction in Phase 2 (Tasks 2.8) when the god screens are refactored. They are noted here for baseline tracking only — do not fix them in isolation as that would touch the god screens prematurely.

---

## 5. Summary

| Item | Result |
|---|---|
| `flutter pub get` exit code | **0 — SUCCESS** |
| Missing required packages | **None** |
| `archive` version | **3.6.1 (v3.x — do not upgrade until Phase 3)** |
| Pre-existing analyzer errors | **0 errors** |
| Pre-existing analyzer warnings | **0 warnings** |
| Pre-existing analyzer infos | **3 (all `onPopInvoked` deprecation, non-blocking)** |

**Verdict:** Environment is healthy. All required packages are present. No blocking analyzer errors. Ready to begin Phase 0 instrumentation tasks.
