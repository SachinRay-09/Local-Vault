# Local Vault — Process Log, Bottlenecks, and Phase 6 Architecture

**App:** Local Vault 2.5.2+6 (post Phases 0–5, October 2026)  
**Devices:** Infinix GT Book (i5-12450H, 16 GB, NVMe) · iQOO Z9x (Snapdragon 6 Gen 1, 6 GB, UFS 2.2)  
**Analysis date:** 2026-10-26  
**Status of this file:** analysis + recommended architecture. No production code was changed in this pass.

This document traces every major process in the **current** tree (after October 2026 work), names remaining bottlenecks, compares them to how similar products do import/export/ZIP/UI in 2025–2026, and recommends a Phase 6 plan that polishes the app **without** changing crypto format, import throughput, or the working job pipeline.

Companion sources: `docs/experience/my_experience_v1.txt`, `.kiro/specs/local-vault-redesign/tasks.md`, `docs/health-check/streaming_native_ux_check.md`, `lib/app/*`, `lib/services/archive_*.dart`.

Older docs (`ARCHITECTURE_AND_DESIGN.md`, `BUGS_PERFORMANCE_AND_IMPROVEMENTS.md`) describe **pre-Phase-1** reality (PointyCastle on the UI isolate, full-ZIP `readAsBytes`, fake thermal services). Those issues are largely **fixed**. Do not treat them as current.

---

## 1. What the app is now (October 2026)

Local Vault is a local-only encrypted media vault for manga/photos/videos:

| Goal | Current status |
|------|----------------|
| AES at rest, no cloud | **Yes.** v1 blobs are chunked AES-256-GCM (`LVCRYPT1`) via Windows BCrypt / Android javax.crypto. v0 CTR blobs still decrypt by magic-header probe. |
| Password cryptographically required | **Yes (Phase 5).** PBKDF2-HMAC-SHA256 (200k) derives a KEK; KEK wraps the 32-byte DEK with AES-256-GCM. Unlock runs KDF in `Isolate.run`. |
| Bulk folder / ZIP import | **Yes, fast.** User-measured: ~750 MB / 224 images in ~10–15 s on GT Book, ~20–30 s on Z9x. Streaming ZIP, one plaintext at a time. |
| Windows ZIP export | **Yes, fast.** Same 750 MB folder in ~30 s. Spinner **jitters** (the main remaining visual issue). |
| Manga handoff | **Yes.** Decrypt-to-temp → Yomikiru / Mihon; cleanup banner on return. |
| Crash recovery | **Partial.** Interrupted jobs are detected; UI only offers Discard. Resume backend exists. |
| Change password | **Backend only.** No Settings UI. |

The user already likes speed. Phase 6 should make daily use **feel finished** (smooth export spinner, password change, resume, theme, progress copy) without touching the native crypto hot path.

---

## 2. Runtime map (how it actually boots)

```
main()
  → IsarDb.open()  (schemas include VaultFile/Folder, AppSettings, FileTag, OperationJob/Item)
  → runApp(VaultApp)
       → MaterialApp, light ColorScheme.fromSeed(0xFF5B5BD6)
       → AuthGate
            → SetupScreen (first run, recovery-policy ack)
            → LoginScreen → AuthSession.unlock
            → HomeScreen (Windows) | MobileHomeScreen (Android)
       → post-frame: _checkInterruptedJobs()  (Discard only)
```

**State:** ChangeNotifier is not used globally. God screens (`home_screen.dart` ~3.2k LOC, `mobile_home_screen.dart` ~2.2k LOC) construct coordinators directly. That is messy internally but **does not hurt import/export speed**. A Riverpod / Clean Architecture rewrite would risk regressions for zero user-visible speed. Leave it.

**On disk:**

- App-support dir: Isar DB (plaintext metadata: names, sizes, folder tree, IVs).
- `vault_blobs/<uuid>.bin` (encrypted payloads; names are random).
- `.partial` blobs during import; atomic rename on commit.

---

## 3. Process-by-process log

Each subsection: **what happens**, **what is already good**, **remaining issue / bottleneck**, **safe fix**.

### 3.1 Unlock (login)

**Process**

1. `LoginScreen` → `AuthSession.unlock(password)`.
2. Lockout check via `SecureStorageService`.
3. `CredentialRepository.hasEnvelope()`:
   - **Envelope (normal after Phase 5):** load salt + wrapped DEK → `DartCryptoEngine.deriveKek` in isolate (PBKDF2 200k) → `unwrapDek` (GCM) → store DEK in `AuthSession.current.dek` (RAM only).
   - **Legacy (first login after upgrade):** verify PBKDF2 hash, wrap DEK, write envelope + rollback marker, delete `master_key_b64`.
4. Navigate to home. Session auto-locks after 5 minutes in background.

**Already good**

- KDF is off the UI isolate (Phase 1.1). Spinner can animate.
- Password is cryptographically required (Phase 5). Wrong password fails GCM tag, not a hash compare of a leftover DEK.
- User-measured: unlock feels quick on both devices.

**Bottleneck (minor)**

- 200k PBKDF2 in Dart is ~100–200 ms on GT Book, ~0.5–1 s on Z9x. That is intentional cost, not a bug.
- First launch after upgrade can be slower (migration). One-time.

**Do not change**

- Do not add biometric (already rejected: duplicates unlock, Android Keystore complexity).
- Do not switch to Argon2 in Phase 6 (new dependency / re-wrap of every envelope).

**Polish**

- Wire **Change Password** UI (Phase 6.2) and **rollback-marker dialog** (Phase 6.4).

---

### 3.2 Folder import (Windows + Android)

**Process**

1. UI picks a folder (Windows `file_picker`; Android multi-file / SAF path).
2. `ImportCoordinator.importFolder`:
   - Enumerate supported extensions (images always; video optional).
   - Sum bytes (`lengthSync`) for progress.
   - Create root vault folder + nested folders via cache.
   - Batch-insert `OperationJob` + `OperationJobItem` (one txn — PERF-003).
3. `JobRunner.run`:
   - For each pending item: thermal pause on Android if ≥ MODERATE (never skip).
   - `BlobStore.createPartialPath` → persist partial path → `NativeCryptoEngine.encryptFile` (v1 default) → delete is N/A (source stays on disk) → `commitPartial` rename → `VaultRepository.addEncryptedBlobRecord` (Isar + `totalBytesUsed` in same txn).
4. Progress stream → dialog `setState` per file.

**Crypto path (v1)**

- Windows: MethodChannel → `crypto_bridge.cpp` → BCrypt AES-256-GCM, 512 KB chunks, detached `std::thread`, AES-NI.
- Android: MethodChannel → `CryptoBridge.kt` → `AES/GCM/NoPadding` (Conscrypt/BoringSSL, ARMv8 CE), background executor.

**Already good**

- Native AES is the real 25–50× win vs old PointyCastle. User: 750 MB in ~10–15 s on PC.
- One file at a time, atomic blob commit, storage counter is O(1).
- Thermal pause no longer drops files.

**Remaining bottleneck (small)**

- Sequential files: GT Book has 8+8 cores idle. Parallel encrypt (2 workers) could shave seconds, but MethodChannel + disk would contend and **risk** thermal/jank on Z9x. User already calls import “instant”. **Do not parallelize in Phase 6.**
- Progress dialog still `setState`s every file. Harmless at ~50–80 ms/file; apply the same coalescer as export for consistency.

---

### 3.3 ZIP import

**Process**

1. UI picks a `.zip`.
2. `ImportCoordinator.importZip` + `ArchiveReader.entries`:
   - Unprotected: `InputFileStream` + decode + `entry.writeContent(OutputFileStream(temp))` + `entry.clear()` before yield.
   - Zip-slip (`..`, absolute, drive letter), symlink, 2 GB bomb → skip entry, continue.
   - Password ZIP: `readAsBytes()` + `decodeBytes` (archive 3.x limitation).
3. Per entry: encrypt temp → delete plaintext temp **before** next entry → commit blob → Isar.

**Already good**

- Unprotected ZIP never loads the archive into Dart heap. Peak extra RAM is one entry (~3 MB) + 512 KB crypto buffers. Safe for a 3 GB ZIP on 6 GB Z9x.
- User: 750 MB ZIP ~20–30 s on phone, **no jitter**.

**Remaining issues**

| Issue | Severity | Phase 6? |
|-------|----------|----------|
| Password ZIP still `readAsBytes` | High if user re-enables large password ZIPs | **Do not re-enable.** Keep the current “no password ZIP export” policy. Document in UI. |
| ZIP import does **not** use `JobRunner` (inline loop; items start as `running`) | Medium for Resume | Fix inside 6.3 Resume: skip committed `originalName`+folder, re-open source ZIP. Do not rewrite the loop. |
| ZIP progress `totalFiles` grows as entries are seen (unknown total until end) | UX | 6.8: show “N files · X MB processed” until central directory is known, or pre-count names only (no inflate). |
| `archive: ^3.4.9` vs archive 4 streaming APIs | Tech debt | **Do not upgrade in Phase 6.** v4 rename (`decodeBuffer`→`decodeStream`) is a compatibility landmine. Current 3.x streaming path already works. |

**Modern reference (keep our pattern)**

Production Dart projects (e.g. Hibiki sync packing) enforce: no `readAsBytes`, no in-memory `ZipEncoder.encode`, `ZipFileEncoder` / `InputFileStream`, `Isolate.run` for codecs, **STORE** for already-compressed bytes. Our **import** already matches the streaming half. Our **export** does not yet.

---

### 3.4 Export (Windows only)

**Process**

1. `ExportCoordinator.exportFolder` (assert Windows).
2. BFS descendant folder IDs → one OR-chained Isar query for files.
3. Open `ArchiveWriter` → `ZipFileEncoder.create(path)`.
4. For each file:
   - Decrypt blob → unique `%TEMP%\lv_export_*.tmp` via `NativeCryptoEngine` (BCrypt, ~1 ms for 3 MB).
   - `writer.addFile(entryName, tempPath)` → **`ZipFileEncoder.addFile` on the Dart UI isolate** (read + DEFLATE + write, ~5–15 ms).
   - Delete temp.
   - `yield ExportProgress` → dialog `setState`.

**Already good**

- One plaintext on disk at a time.
- Native decrypt is not the bottleneck (user suspected CPU burst; measurements show BCrypt <1 ms).
- 750 MB / 224 files in ~30 s — speed is already excellent.

**Bottleneck (the one users see)**

```
BCrypt decrypt (C++ thread, <1 ms)  →  UI isolate free
ZipFileEncoder.addFile              →  UI isolate BLOCKED 5–15 ms  ← jitter
setState + spinner rebuild          →  extra frames
```

Flutter wants a frame every ~8–16 ms. A 5–15 ms sync ZIP add drops 1–2 frames per file; over 224 files the spinner looks drunk.

**Wrong fix (do not do this)**

The original Task 6.1 draft said: `Isolate.run` → `readAsBytes` into `Uint8List` → `addArchiveFile` on the UI isolate.

That:

- Puts a **full file in RAM** (videos, 100 MB pages → OOM risk).
- Still does ZIP central-directory work on the UI isolate.
- Fights the streaming rule that made import fast.

**Right fix (Phase 6.1, revised)**

Keep `archive` 3.x. Do **not** add `zcodec`.

1. **Long-lived ZIP worker isolate** that **owns** `ZipFileEncoder` for the whole export (handles cannot cross isolates, so the encoder must live in one worker, not per-file `Isolate.run`).
   - Main isolate: decrypt → temp path (unchanged).
   - Send `(entryName, tempPath)` to worker; worker `addFileSync(File, name, storeLevel)`; ack; main deletes temp.
2. **STORE (compression level 0)** for already-compressed types: `.jpg/.jpeg/.png/.webp/.gif/.avif/.mp4/.mkv/.avi`. DEFLATE on JPEG is wasted CPU and is most of the 5–15 ms. STORE is how manga/CBZ and media packagers ship pages.
3. **Coalesce `setState`** (latest-value-wins, one rebuild per frame) on export **and** import dialogs.

Result: same ZIP compatibility (STORE is universal), often **faster** export, spinner stays at 60 fps, RAM still one file on disk / none extra in Dart heap.

---

### 3.5 View / browse images

**Process**

1. Grid/list in home screen; natural sort.
2. Tap → `ImageViewerScreen`: decrypt via `VaultOpenService` (`NativeCryptoEngine` default) to temp file → `precacheImage` → `AnimatedSwitcher` fade. No `PageView` slide (that caused black flash on Previous).
3. Keep ±2 decoded, evict beyond ±4 (`imageCache.evict` + delete temp). Prevents the old “stutter after 200 images” OOM.

**Already good**

- PC: user reports navigation is great after October fixes.
- Mobile: no 200-image stutter. Occasional one-frame black on **very large** rasters while GPU uploads ~90 MB textures.

**Bottleneck**

- GPU texture upload on Z9x for 4000×6000 pages. Decrypt is ~8 ms; decode+upload dominates.

**Do not change in Phase 6**

- User explicitly rejected `ResizeImage` downscale (quality). One-frame flash on huge pages is accepted.

**Optional later (not Phase 6)**

- Wait 1–2 frames after `precacheImage` before switching (adds 16–32 ms latency, hides black). Only if it still bothers daily use.

---

### 3.6 Manga export (Yomikiru / Mihon)

**Process**

Decrypt folder tree to a temp directory → launch external reader → user reads → return to app → cleanup banner / manual clear in Settings.

**Already good**

- Native decrypt made Mihon open feel quick.
- Banner persistence until dismiss is intentional.

**Bottleneck**

- Full chapter plaintext on disk is a **product tradeoff** (external apps cannot read vault blobs). Keep.

**Polish**

- Settings already has “Clear temp cache”. Surface it more clearly after a session (already exists). No architecture change.

---

### 3.7 Search, tags, move, storage

| Feature | Status | Phase 6? |
|---------|--------|----------|
| Name search | Works | No |
| FileTag schema | Exists, UI incomplete | **Deferred** (tasks.md already). Design work, not a speed win. |
| Natural sort + batch move | Works | No |
| `totalBytesUsed` counter | Incremental, reconcile on first run | No |
| Storage limit in Settings | Works | Show a **bar + GB used** (6.8/6.7 visual), not a new engine |

---

### 3.8 Crash recovery and password-change atomicity

**Process today**

- On startup, `findInterruptedJobs`. If `.partial` files exist, dialog: Discard only. TODO in UI still says “Phase 3 resume”.
- ZIP items are `running` (not `pending`), so `JobRunner` would not pick them up even if Resume called `run()` blindly.
- Password change writes a rollback marker; if killed, marker is **not** shown on next launch.

**Value of fixing**

- Resume: real daily-use value if a 2 GB import is killed. Must skip committed blobs and re-open source path; if source gone → Discard only.
- Rollback dialog: rare, but prevents “why is my new password not working?” after a crash mid-change.

Neither changes crypto or import speed.

---

## 4. What similar / better projects do (internet, 2025–2026)

### 4.1 ZIP / import-export

| Practice | Who / where | Apply here? |
|----------|-------------|-------------|
| Stream ZIP from disk (`InputFileStream` / `OutputFileStream`), never `decodeBytes` of whole archive | archive 4 design notes; Hibiki packing tests | **Already on import.** Keep. |
| ZIP work on a **background isolate**; UI isolate never DEFLATEs | Hibiki `Isolate.run` + `ZipFileEncoder` | **Phase 6.1** as a long-lived worker, not per-file byte buffers. |
| **STORE** method for JPEG/PNG/WebP/audio/video | CBZ/manga pipelines; Hibiki `ZipFileEncoder.STORE` | **Phase 6.1.** Biggest cheap win. |
| Native AES (CNG / OpenSSL / Conscrypt), chunked AEAD | Cryptomator, VaultExplorer, our Phase 4 | **Already done.** |
| Password ZIP via PKWARE in Dart | archive 3.x | **Avoid.** RAM bomb; we already dropped password export. |
| Upgrade to archive 4 or add `zcodec` ZipStreamWriter | archive 4 / pub.dev zcodec | **Not Phase 6.** New API + risk. Revisit only if STORE+isolate is insufficient. |
| Parallel encrypt workers | Desktop backup tools | **Not Phase 6.** Speed already loved; Android thermal risk. |

### 4.2 Vault / private-media UX

| Practice | Examples | Apply here? |
|----------|----------|-------------|
| Dark / OLED as default for media vaults | Cryptomator 1.15, Privi, Arcile, PhotoVault redesign | **Yes.** ThemeMode.system + dark `ColorScheme.fromSeed` same indigo seed. Light remains. |
| Material 3 surfaces, not a visual rewrite of the file tree | Arcile, Cryptomator compact list | **Yes.** Theme + progress + settings grouping. **Do not** rebuild HomeScreen. |
| Screenshot block (`FLAG_SECURE`) while unlocked | Cryptomator, VaultStream | **Optional toggle, default off.** User may want to screenshot manga for personal notes; forcing it breaks that. |
| Biometric unlock | Most vault apps | **No.** User + tasks.md already rejected. |
| Breadcrumbs, grid/list, search | VaultExplorer, our app | Already have grid/list + search. Breadcrumb chip on mobile is a small plus, not required. |
| Honest recovery copy | Cryptomator unlock errors | Already on SetupScreen. Repeat a one-liner in Settings Security. |

---

## 5. Target architecture for Phase 6 (do not fork the pipeline)

Keep the October 2026 pipeline. Only move **ZIP encode** and **progress UI** off the jank path.

```
IMPORT (unchanged)
  source folder/ZIP
    → ArchiveReader (stream) | directory walk
    → JobRunner / importZip loop
    → NativeCryptoEngine (BCrypt / javax.crypto)
    → BlobStore atomic rename
    → Isar + storage counter
    → coalesced progress UI

EXPORT Windows (changed in 6.1 only)
  subtree query
    → NativeCryptoEngine.decrypt → one temp file
    → ZIP WORKER ISOLATE (owns ZipFileEncoder, STORE for media)
    → delete temp
    → coalesced progress UI
```

**Hard constraints (do not violate)**

- No crypto format change. v1 stays default; v0 still decrypts.
- No new pub dependencies.
- No biometric, no filename encryption, no Riverpod, no Clean Architecture move.
- No `ResizeImage` in the viewer.
- No password-protected ZIP.
- No `readAsBytes` of media or of unprotected ZIPs.
- Do not change `JobRunner` concurrency (1 Android / current Windows).

---

## 6. Phase 6 task-by-task: worth it? what it fixes?

Scoring: **Keep / Revise / Defer / Drop**. “User value” is daily-use polish vs risk to the fast path.

### 6.1 Export ZIP off UI thread + STORE — **Keep, but revise implementation**

| | |
|--|--|
| **Fixes** | Visible spinner jitter on GT Book (the only performance complaint in v1 notes). Also slightly faster export (skip JPEG DEFLATE). |
| **User value** | High. Export is the remaining “feels cheap” moment. |
| **Risk** | Medium if done with in-memory bytes. **Low** with worker isolate + STORE + streaming `addFile`. |
| **Breaks current system?** | No if ZIP still standard (STORE + DEFLATE mix is valid ZIP). Re-import test is mandatory. |

**Implementation (replaces the byte-buffer draft):**

- `ArchiveWriter` talks to a spawned isolate via `SendPort`.
- Commands: `open(path)`, `add(entryName, filePath, store: bool)`, `close()`.
- `store: true` when extension is in the compressed-media set.
- Progress coalescer in `_ExportCoordinatorProgressDialogState`.

### 6.2 Change-password UI — **Keep as-is**

| | |
|--|--|
| **Fixes** | Backend exists (`AuthSession.changePassword`) with no entry point. User cannot rotate a leaked password. |
| **User value** | High for a privacy product; zero effect on import speed. |
| **Risk** | Low if PBKDF2 stays inside existing isolate path and rollback marker is kept. |

### 6.3 Crash Resume UI — **Keep, with ZIP caveat documented in the task**

| | |
|--|--|
| **Fixes** | Kill mid-import currently wastes work (Discard only). |
| **User value** | Medium–high on 1–2 GB phone imports. |
| **Risk** | Medium if Resume blindly calls `JobRunner` on ZIP jobs (items are `running`, source is ZIP not folder). **Must** branch: folder → `JobRunner` pending items; ZIP → re-open zip, skip names already in destination folder. If source missing → Discard only. |
| **Breaks?** | No if Discard path stays identical. |

### 6.4 Rollback-marker dialog — **Keep**

| | |
|--|--|
| **Fixes** | Interrupted password change can leave a confusing marker. Rare. |
| **User value** | Low–medium. Cheap insurance before 6.2 ships. |
| **Risk** | Low. No blob I/O. |

### 6.5 Delete deprecated services — **Keep, last**

| | |
|--|--|
| **Fixes** | Confusion, APK weight, accidental calls to placeholders. |
| **User value** | Low (invisible). Developer value high. |
| **Risk** | Medium if a forgotten import remains. Grep + `flutter analyze` gate. |
| **Do not delete** | `import_export_service.dart` pickers, `file_crypto_service.dart`. |

### 6.6 Opt-in v0→v1 migration — **Keep, optional, after 6.1–6.4**

| | |
|--|--|
| **Fixes** | Leftover v0 blobs lack AEAD; viewing them uses slower Dart CTR. User already on v1 for **new** files. |
| **User value** | Medium only if the vault still has Phase-1-era files. Fresh installs: empty. |
| **Risk** | Medium if automatic. **Must stay opt-in**, per-file commit, interrupt-safe (magic header). |
| **Do not** force migrate; do not block browsing during migrate. |

### New 6.7 — System / dark / light theme — **Add (UI/UX)**

Vault apps users actually like (Cryptomator 1.15, Privi, Arcile, PhotoVault) are dark-first. We ship **light-only** `ColorScheme.fromSeed` in `VaultApp`.

- `ThemeMode.system` default + Settings: System / Light / Dark.
- Dark: `ColorScheme.fromSeed(seed: 0xFF5B5BD6, brightness: dark)`. Slightly elevated surface containers (not pure #000 unless an optional OLED toggle later).
- Persist in `AppSettings` (already an Isar collection).
- **Does not** restyle every widget by hand; Material 3 components follow the scheme.
- **Does not** change layout, navigation, or import dialogs’ logic.
- Full implementer spec (roles, hardcoded-color inventory, cinema viewer exception): `docs/design/THEME_DARK_LIGHT_IMPLEMENTATION.md`.

### New 6.8 — Progress + Settings visual polish — **Add (UI/UX, no engine change)**

Import/export dialogs today: spinner + “n / m files”. Settings: raw counts.

- Reuse 6.1 coalescer on **import** dialogs (desktop + mobile).
- Show `processedBytes / totalBytes` (coordinator already emits this) and a linear bar.
- Settings: used-storage linear indicator; Security section (Change password, lock, recovery one-liner); Appearance section (theme).
- Replace stale dialog copy “Full resume support is planned for Phase 3.”

No pipeline changes.

### New 6.9 — Optional screenshot blocking — **Add as Settings toggle, default OFF**

Cryptomator/VaultStream use `FLAG_SECURE` while unlocked. For this app, screenshots of manga are a reasonable personal workflow.

- Android: `FLAG_SECURE` when toggle on.
- Windows: skip or no-op (no equivalent without extra plugins).
- Default **off** so current behaviour is unchanged.

### Explicitly still out of Phase 6

- Biometric, filename encryption, Riverpod, Clean Architecture, tag-search redesign, `ResizeImage`, archive 4 upgrade, password ZIP, parallel JobRunner, encrypting Isar metadata.

---

## 7. Suggested Phase 6 order (safe)

```
6.1 ZIP worker isolate + STORE + export coalescer     ← only speed/feel leftover
6.8 coalescer + byte progress on import dialogs       ← same UI pattern, tiny
6.2 Change password UI
6.4 Rollback-marker dialog   (ship with or just before 6.2)
6.3 Resume (folder first; ZIP skip-already-imported)
6.7 Theme (system/dark/light)
6.9 FLAG_SECURE toggle (default off)
6.5 Delete deprecated files
6.6 Opt-in v0→v1 migrate     (only if mixed-format vaults exist)
```

Each task stays independently shippable. Vault health check after every task. If anything threatens import MB/s, revert that task only.

---

## 8. Expected user-visible result

| Surface | Today (loved) | After Phase 6 |
|---------|----------------|---------------|
| Unlock | Fast, secure envelope | Same + can change password |
| Import 750 MB | 10–15 s PC / 20–30 s phone | Same speed; smoother counter |
| Export 750 MB | ~30 s, jittery spinner | ~same or faster (STORE); smooth spinner |
| Viewer | Good; rare huge-page flash on phone | Unchanged (by design) |
| Kill mid-import | Discard only | Resume or Discard |
| Look | Light Material 3 | System/dark/light, same layout |
| Codebase | Deprecated ghosts | Deleted after grep |

The product stays the fast vault from October 2026. Phase 6 is polish on top, not a second rewrite.
