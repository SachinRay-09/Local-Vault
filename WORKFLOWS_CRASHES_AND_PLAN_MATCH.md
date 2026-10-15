# App Workflows, Hardware/Process Behavior, Crashes, and Plan Match

This file is the **runtime map** of Local Vault 2.5.2 as the code actually runs on **Windows (GT Book class)** and **Android (iQOO Z9x class)**. It then scores the verified architecture (`IMPROVEMENT_PLAN_VERIFIED.md` + `Copilot_response.md`) against each step: does the new design fix freezes, OOM, leftover plaintext, and keep manga folder import/export working?

There are **no Android/Windows OS background services** belonging to this app. Work runs inside the **one Flutter process** (UI isolate + optional Dart isolates + plugin threads). “Background” in the current app means: `Future`s on the UI isolate, a 10-second delayed cleanup timer, or a detached child process (Yomikiru / Mihon).

---

## How to read “hardware / CPU / process”

| Layer | What actually exists |
|--------|----------------------|
| **OS process** | One `local_vault.exe` (Windows) or `com.yourname.local_vault` (Android) |
| **UI / GPU** | Flutter raster + GPU compositor. Windows: D3D. Android: hardware-accelerated Activity |
| **CPU (UI isolate)** | Dart main isolate: frames, buttons, **PBKDF2, AES, ZIP decode today** |
| **CPU (other)** | PointyCastle AES is software (no AES-NI / ARMv8 crypto). GPU is unused for encryption |
| **Disk** | SSD (PC) / UFS (phone): Isar DB, `vault_blobs/*.bin`, temp plaintext |
| **Secure storage** | Windows Credential Manager / DPAPI via `flutter_secure_storage`; Android EncryptedSharedPreferences / Keystore-backed prefs |
| **Other processes** | File picker, Explorer, Yomikiru.exe, Mihon — started by this app, not owned by it |
| **No** | WorkManager, Foreground Service, Windows Service, isolate pool in production import |

**Typical crash classes (not a debugger log — inferred from code paths):**

| Symptom | Likely cause | Where |
|---------|--------------|--------|
| App “frozen” 0.5–3s then recovers | Sync PBKDF2 120k on UI isolate | Unlock |
| Frozen for minutes / “not responding” | AES + ZIP on UI isolate | Import / export / Mihon decrypt |
| Instant kill on phone (no Dart exception) | **OOM** — `readAsBytes()` of ZIP / TAR container | Import ZIP, container strategy |
| Import “succeeds” with missing pages | Thermal pause **skips** the file | `EnhancedVaultRepository` |
| Temp still on disk after “clear” | Mihon path is **outside** app temp | See §5–6 |
| Dialog gone after reading | Process killed or route popped | See §5 |

---

# 1. First open, password, freeze, recovery

## 1.1 First launch (no vault yet)

**Process**

1. OS starts the app process. Windows: `wWinMain` → Flutter engine → Dart `main()`. Android: `MainActivity` (FlutterActivity) → same `main()`.
2. `WidgetsFlutterBinding.ensureInitialized()` — Flutter attaches to the window / Activity.
3. Windows: optional FVP register (currently commented in `pubspec.yaml` — skipped).
4. `HardwareAccelerationService.initialize()` — **spawns `wmic` / PowerShell or reads `/proc/cpuinfo`**. Detects AES-NI/NEON then **does not change crypto**. Extra I/O on first frame.
5. `MemoryManagementService.optimizeMemorySettings()` — only tweaks Flutter `imageCache` size (30 MB Android / 100 MB desktop).
6. Image cache cleared.
7. `IsarDb.open()`:
   - `getApplicationSupportDirectory()`
     - **Windows:** `%APPDATA%\com.yourname\local_vault` (or similar support path)
     - **Android:** `/data/user/0/<package>/files` (app-private)
   - Creates `vault_blobs/`
   - Opens Isar mmap files (`local_vault.isar`) — CPU + disk; typically tens of ms
8. `runApp(VaultApp)` → `AuthGate` → `AuthService.loadState()` → `SecureStorageService.hasPassword()`.
9. No password keys → **SetupScreen**.

**Hardware:** one process, UI isolate blocked until Isar opens; Keystore/Credential Manager read; no bulk AES yet.

**Crashes:** rare. Isar open failure (disk full / corrupted DB) throws and the app never reaches UI.

**Plan match:** Keep Isar. Move hardware “detection” off the critical path or delete it. **Solves:** first-frame hitch from `wmic`/PowerShell. **Does not change** setup UX.

## 1.2 Setup (create password + two questions)

`AuthService.setup`:

1. `getOrCreateMasterKey32()` — 32 random bytes → secure storage as `master_key_b64`.
2. `setPassword` — random 16-byte salt; **PointyCastle PBKDF2-SHA256, 120 000 iterations, 32-byte hash** — **synchronous on UI isolate**.
3. Security Qs: plaintext question text + salt + **single SHA-256(answer+salt)** (fast, not a slow KDF).

**Why the first setup can freeze:** same as unlock — 120k PBKDF2 in software Dart on the UI thread. GT Book: ~0.3–1.5 s. Z9x: often ~1–3 s. Flutter drops frames (jank), spinner may not even animate.

**If setup is killed mid-write:** possible partial keys in secure storage (hash without questions). User may need reinstall or storage wipe.

**Plan match:** KDF in `Isolate.run` / native. **Improves freeze.** Envelope (KEK wraps DEK) is a **later** phase with migration so this first-run still works.

## 1.3 Later launches — enter password — why freeze

```
LoginScreen._unlock
  → lockRemaining()          // secure storage read
  → verifyPassword
       → isLockedOut
       → read salt, hash, iterations
       → _pbkdf2Sha256(...)  // BLOCKS UI ISOLATE
       → constant-time compare
       → reset or increment failed-attempt counters
  → Navigator.pushReplacement(HomeScreen | MobileHomeScreen)
```

**Hardware:** CPU pegged on **one core** (Dart isolate is single-threaded). AES-NI idle. GPU idle. Disk: a few Keystore reads/writes.

**Why freeze:** PBKDF2 is *meant* to be slow, but it runs **where frames are painted**. The button shows a `CircularProgressIndicator`, but that indicator often **does not spin** because the isolate cannot process vsync.

**Success:** in-memory navigation only. Master key stays in OS secure storage; it is **not** derived from the password. Home then queries Isar for root folders/files (`listFolders` / `listFiles`).

**Plan match:** Off-UI KDF → **freeze gone**, KDF still 200–800 ms in a worker (OWASP: typically &lt; 1 s). Password-wrapped DEK later: wrong password **cannot unwrap** blobs (stronger than today).

## 1.4 Wrong password

- Compare fails → increment `auth_failed_attempts`.
- ≥5 tries: lock 30 s; ≥8: 2 min; ≥10: 5 min. Stored as `auth_lock_until_ms`.
- UI: “Incorrect password.” + lock hint.
- **Does not** wipe vault. **Does not** touch blobs.

**Crashes:** none expected.

**Plan match:** Keep lockout. Run KDF in background so the error message appears without a freeze.

## 1.5 Security questions → password change

Forgot password → load question **texts** (plaintext in secure storage) → `RecoveryScreen`.

Answers: SHA-256(answer+salt), constant-time compare, **both** must match → `resetPassword` → **new PBKDF2 hash only**. **Master key unchanged.**

**Implication:** Anyone who knows the two answers can set a new app password and then open the vault, because encryption is **not** bound to the password. Questions are a **second UI gate**, not cryptographic recovery.

**Plan match:** After KEK/DEK wrap, this flow **must change** or it will **break** “I forgot password but remember questions.” Verified plan: either (a) questions wrap a recovery secret, or (b) no recovery — forgotten password = data unreadable. Must be chosen in spec so manga libraries are not silently bricked.

## 1.6 Forgotten password **and** forgotten questions

**Today:** there is **no third factor**. Vault blobs remain on disk; UI cannot unlock. Reinstall does not help unless secure storage + files remain. If the user still has the files and a backup of `master_key_b64`, they could theoretically decrypt outside the app — the password is not required for the bytes.

**Plan (wrapped DEK):** forgotten both → **permanent loss** unless a printed/OS recovery key exists. This is correct for a real vault; it is a **product warning at setup**, not a bug.

---

# 2. After unlock — folders (create / rename / move)

All of these are **Isar metadata only**. Encrypted blobs **do not move** on disk. Folder tree is `parentId` pointers.

| Action | Code | Disk / CPU | Crash risk |
|--------|------|------------|------------|
| Create folder | `VaultRepository.createFolder` — one write txn, `VaultFolder` row | Tiny SSD write | Very low |
| Rename folder | Update `name` + `updatedAt` | Tiny write. Blob filenames stay random `.bin` | Very low |
| Move into another folder / root | `moveFolder`: cycle check (`_isAncestorOrSelf`) then `parentId = newParentId` | Tiny write. **No** file copy | Cycle throws `StateError`; UI snackbar |
| Batch move | Single txn | Faster | Same validation |

**Hardware:** UI isolate + Isar mmap. No AES. Should feel instant on both devices.

**UI:** Desktop `HomeScreen` / mobile `MobileHomeScreen` hold `_currentFolderId` + stack; `_refresh()` re-queries children and **natural-sorts** folder names in Dart.

**Crashes:** none for these ops. Worst case: Isar write error (disk full).

**Plan match:** Keep as-is. ViewModels should call the same repository so desktop/mobile don’t duplicate. **No performance problem here.** Optional later: encrypt names after unlock (session index) — **not** v1 (would break search/sort).

---

# 3. Export (PC) and import (PC + mobile)

## 3.1 Windows — export folder or whole vault

`ImportExportService.exportAllToZip` / `exportFolderToZip`:

1. Create `%TEMP%\local_vault_export_*` or `local_vault_folder_export_*`.
2. Load **all** folders/files from Isar (folder export still loads all then filters).
3. For **each** file: `decryptBlobToFile` — PointyCastle AES-CTR **on UI isolate**, write **plaintext** into staging (original names, folder tree).
4. `ZipFileEncoder` (optional password) zips the staging tree.
5. Delete staging in `finally`.

**Hardware (GT Book):** one CPU core software AES; SSD write amplification (decrypt write + zip read + zip write). RAM: staging files on disk, ZIP encoder buffers. GPU unused.

**Crashes / failures:**

- Disk full during staging.
- UI freeze / “App not responding” on large libraries (Windows may dim the window).
- Password ZIP extra CPU.
- If user kills the app mid-export: leftover `%TEMP%\local_vault_*` until Clear temp / close cleanup.

**Plan match:** Stream decrypt → ZIP entry, no full-vault staging; job + cancel; Windows-only export. **This is the right PC → phone pipeline.** Mobile export stays **out of scope**.

## 3.2 Windows — import folder

User types a path (not a real directory picker). `BulkImportService`:

1. Recursive list — **image extensions only** (jpg/png/webp/…). **Videos silently skipped.**
2. `createFolder` for root.
3. Batches of **3** files + **100 ms sleep**.
4. Each file: `repo.addMedia` → stream encrypt to `vault_blobs/<random>.bin` + Isar row. **Still UI isolate.** Comment says “isolate”; code does not.

**Crashes:** UI freeze; thermal not involved on desktop. Incomplete import if killed: some blobs + folders exist (no job recovery).

**Plan match:** One enumerator + job + per-file commit; include manga images (keep videos optional); remove sleeps; native/path encrypt. **Critical for “import works smoothly.”**

## 3.3 Windows — import ZIP

`importFromZip` → **`zipFile.readAsBytes()`** (entire archive in RAM) → `ZipDecoder.decodeBytes` → extract to Documents `vault_import_*` → `_importExtractedTree` → `addMedia` per file → delete extract dir.

**Crashes:** RAM spike; 1 GB ZIP ≈ 1 GB+ Dart heap. GT Book 16 GB usually survives; still janky.

## 3.4 Android — import folder

No real tree picker. Multi-file pick → `EnhancedVaultRepository.addMultipleMedia` (strategy: individual / **in-memory container** / hybrid). Individual path = `addMedia` per file + fake battery/thermal delays; thermal **skip** can drop pages.

**Crashes:** OOM if container TAR in RAM; ANR; missing pages.

## 3.5 Android — import ZIP (PC → phone)

Picker → optional password → SAF `SafZipImportService` **or** fallback `UnifiedImport` / legacy `readAsBytes`. Same extract-then-encrypt pattern. Extra copies into `cache/local_vault_zip_*`.

**Z9x (6 GB):** this is the **highest crash path** (LMK kill).

**Plan match:** Streaming ZIP entry-by-entry; never `readAsBytes`; one job engine both platforms; Android import only. **This is the #1 pipeline fix.**

---

# 4. How data is stored “securely” — pipeline

## 4.1 What is encrypted vs not

| Data | Location Windows | Location Android | Encrypted? |
|------|------------------|------------------|------------|
| File bytes | `%APPDATA%\...\vault_blobs\*.bin` | app-private `files/.../vault_blobs/*.bin` | AES-256-CTR (PointyCastle), per-file IV in Isar |
| Names, folder tree, sizes | Isar in support dir | Same | **No** |
| Master AES key | flutter_secure_storage | flutter_secure_storage | OS store; **not** wrapped by password |
| Password verifier | same | same | PBKDF2 hash |
| Security Q text | same | same | **No** (plaintext questions) |
| Viewer / manga plaintext | `%TEMP%\vault_tmp`, `local_vault_yomikiru\...` | app `cache/vault_tmp`, **and** `/storage/emulated/0/Manga/LocalVault/manga_temp/...` | **No** while present |

**Pipeline (import one page):**

```
Source image (user disk / ZIP entry)
    → (today: UI isolate) AES-CTR stream → vault_blobs/<id>.bin
    → Isar VaultFile { originalName, storedBlobName, ivBase64, parentFolderId, sortOrder }
```

**Pipeline (open in-app image):**

```
Isar row → read blob → decrypt to vault_tmp/<blob>--<name> → Image widget / PageView
```

`VaultOpenService.decryptToCachedTempFile` writes **plaintext cache** (24 h cleanup of old files only).

**Hardware:** software AES, sequential I/O. Phone thermal + 6 GB RAM make large sequential decrypt painful.

**Security gap vs goal (“only accessible after password”):** OS user who can read app files still needs Keystore/Credential Manager for the DEK. A copied `vault_blobs` folder **without** secure storage cannot decrypt. A copied vault **plus** extracted key **can**. Password is UI. After plan Phase 5, password (or recovery key) is required to unwrap DEK.

**Plan match:** Keep blob-per-page (manga). Versioned AEAD later. Honest metadata until name encryption. **Does not break** chapter trees.

---

# 5. Mihon / Yomikiru — temp folders, dialogs, Clear temp

## 5.1 Windows — Open in Yomikiru

1. Progress dialog (not dismissible).
2. Create `%TEMP%\local_vault_yomikiru\<sanitizedFolderName>\`.
3. Recursively collect **images** in that vault folder; decrypt each to that tree (PointyCastle, UI isolate).
4. `cmd /c start Yomikiru.exe <path>` (hardcoded paths include a user-specific `C:\Users\raysa\...`).
5. Success dialog: path, Keep Reading, **Clean Up**, Open Folder. `barrierDismissible: false`.

**Where files live:** Windows user temp, **not** inside the vault. Yomikiru is a **separate process** reading plaintext.

## 5.2 Android — Open in Mihon

1. Storage permission check (`MANAGE_EXTERNAL_STORAGE` / media perms). Fail → snackbar, no export.
2. Detect Mihon via `canLaunchUrl(tachiyomi://...)`.
3. Base path from settings, default **`/storage/emulated/0/Manga/LocalVault`**.
4. Create `.../manga_temp/<folderName>/` (delete if exists).
5. Decrypt all images there.
6. Try launch Mihon / other readers with the folder.
7. Success dialog: Keep Reading / **Clean Up**.

**Hardware:** full chapter decrypt on UI isolate; writes to **shared storage** so Mihon (another UID) can read. That is why it is **not** app-private cache.

## 5.3 “Clean temp after read” dialog if you switch apps

| What you do | Dialog still there? | Temp files? |
|-------------|---------------------|-------------|
| Switch to Yomikiru/Mihon, Local Vault **stays in RAM** | **Yes.** Route is still on the stack (`barrierDismissible: false`). Resume → same dialog | Stay until Clean Up / Keep Reading |
| Android **kills** Local Vault (memory) | **No.** Process gone; dialog state not persisted | **Plaintext remains** under `Manga/LocalVault/manga_temp/...` |
| Windows close Local Vault while Yomikiru open | Dialog gone. Close cleanup tries to delete dirs whose names contain `yomikiru` under **system temp** | May delete while Yomikiru has files open (delete fail or reader breaks) |
| Tap **Keep Reading** | Dialog closes. **No path stored** for later | Files remain until Clear temp **if** that path is in the cleanup allowlist |
| Tap **Clean Up** | Deletes **that exact folder** (`cleanupMangaReaderTemp` / `cleanupTempFolder`) | Gone |

**There is no saved “pending cleanup” job.** If the dialog is gone, the in-dialog Clean Up button **cannot** come back.

## 5.4 Top-bar / Settings “Clear temp cache”

Both shells call `AppLifecycleService.performManualCleanup()`:

- `VaultPaths.tempDir()` → OS temp + `vault_tmp` (in-app decrypt cache)
- System/app temp dirs matching `local_vault_zip_*`, `container_`, `yomikiru`, `vault`, `manga_reader`
- App cache `local_vault_zip_*`
- Android **external cache** entries with `vault` / `local_vault` in the **name**

**Windows:** this **does** remove `%TEMP%\local_vault_yomikiru\...` — so top-bar Clear temp **does** the work of the missing dialog for Yomikiru.

**Android:** default Mihon dump is **`/storage/emulated/0/Manga/LocalVault/...`**, which is **not** app temp and **not** scanned by this cleanup. **Top-bar Clear temp does *not* delete Mihon reading folders.** Only the dialog Clean Up (or a file manager) does.

**Plan match:** Persist `OperationJob` of type `decryptForViewer` with `tempPath`; on resume show “Clean leftover plaintext”; Clear temp must include **registered** manga temp dirs only, not all of `/storage/emulated/0`. Bound cache to selected chapter. **Fixes the switch-app gap.**

---

# 6. Clear temp vs other files on the device (safety)

**Vault library (blobs + Isar) is never deleted by Clear temp.** Paths are under application support, not in the temp scanners.

**Intended deletes (app-created):**

| Path pattern | Purpose |
|--------------|---------|
| `.../vault_tmp` | In-app decrypt cache |
| `%TEMP%/local_vault_yomikiru/` | Yomikiru plaintext |
| `%TEMP%/local_vault_export_*` | Export staging |
| app cache `local_vault_zip_*` | ZIP import copies |
| `container_*` under OS temp | Container strategy leftovers |

**Does not walk:** DCIM, Downloads, Documents, other apps, vault_blobs, user manga libraries **except** the app-created `Manga/LocalVault/manga_temp` which **also is not** cleared by the button (see §5.4).

**Residual risks (narrow):**

1. On **app close**, `_cleanupAllTempDirectoriesOnClose` lists **`Directory.systemTemp`** and deletes any **directory whose last path segment contains** `vault`, `local_vault`, `container_`, or `yomikiru`. That is **only the OS temp folder**, not the whole disk. Unlikely to hit user data; could hit another tool’s temp folder named e.g. `vault-backup` in `%TEMP%`.
2. Manual cleanup `name.contains('vault')` in **app** temp/cache — same idea, app-scoped on Android (`getTemporaryDirectory` is the app cache).
3. Mihon Clean Up deletes **only** the `tempFolderPath` string created this session — should be `.../manga_temp/<chapter>`. It does **not** delete all of Mihon or DCIM.
4. Lifecycle cleanup after **10 s paused** deletes import/export temps matching `yomikiru_export` (note: actual Yomikiru dir is `local_vault_yomikiru`, so **pause cleanup does not currently wipe Yomikiru reads**). Good for reading; leftover ZIP extract dirs may linger 30+ minutes (`vault_tmp` only if &gt; 30 min old).

**Verdict:** Clear temp is **mostly safe** for other user files and **does not** wipe the encrypted vault. It is **incomplete** for Android Mihon plaintext (privacy leftover) and **aggressive** for Windows Yomikiru temp (correct if the user wants cache gone). Plan should use an **explicit allowlist of directories this app created**, registered in a job table — never substring-match `vault` across temp.

---

# Plan match matrix (does the new architecture fix it?)

| Workflow pain | Current | Verified plan | On GT Book | On Z9x |
|---------------|---------|---------------|------------|--------|
| Unlock freeze | PBKDF2 on UI isolate | KDF in isolate/native; UI stays at 60 fps | **Fixed** | **Fixed** |
| Wrong password freeze | Same KDF | Same | **Fixed** | **Fixed** |
| Questions vs wrapped DEK | Reset keeps DEK | Spec must pick recovery policy | **Must not ship wrap without this** | Same |
| Folder create/rename/move | Already cheap | Unchanged | Fine | Fine |
| Import freeze / OOM | ZIP `readAsBytes`, UI AES, sleeps, container RAM | Stream ZIP, path crypto, jobs, no container default | **Much better** | **Must-have** |
| Silent skipped images (desktop) | Images-only bulk | Import all manga types; no silent skip | **Fixed** | N/A / multi-pick |
| Thermal skip pages | `return false` | Pause/resume job item | N/A | **Fixed** |
| Export PC→phone | Full decrypt staging | Stream to ZIP; Windows only | **Better CPU/disk** | Import side streaming |
| Password ≠ crypto | Key in OS store | KEK wraps DEK after migration | **Security upgrade** | Same |
| Mihon dialog lost | No persistence | Job + leftover plaintext UI | Yomikiru: Clear temp already helps | **Needed** |
| Clear temp vs Mihon path | Misses `Manga/LocalVault` | Allowlist of created temps | OK | **Fixes leftover pages** |
| Clear temp vs user files | App temp + name filters | Allowlist only | Safer | Safer |
| Fake perf services | Extra delays | Delete / quarantine | **Faster imports** | **Faster imports** |
| God screens | Logic in 2k-line widgets | Shells + coordinators | Maintainability | Same |

**Pipeline will work on both devices if** phases 0–3 land first (measure, off-UI KDF, one import job, streaming ZIP, per-file commit, Windows-only stream export, registered temp cleanup). Native AES (phase 4) then uses AES-NI / ARM crypto so GT Book and Z9x actually use their silicon. Phase 5 (password wrap) must not run until recovery copy is decided — otherwise “forgot password, remember questions” **breaks** the product.

---

## Short answers to the six questions

1. **First open:** Flutter engine + Isar + empty secure storage → setup. **Password:** 120k PBKDF2 on the **UI thread** → freeze. **Wrong password:** lockout counters, no wipe. **Questions:** SHA-256 answers; reset password only. **Forgot both:** no recovery today; after real crypto wrap, that is permanent unless a recovery key exists.

2. **After unlock:** Isar lists folders. **Create/rename/move** only change `parentId`/`name` in the DB — blobs stay put. Cheap, safe.

3. **PC export:** decrypt all selected → temp → ZIP. **PC import folder:** sequential software AES, images only. **PC/mobile ZIP import:** often **whole ZIP in RAM** then re-encrypt. **Mobile folder:** multi-pick + same AES; container path can OOM.

4. **Storage:** encrypted blobs in app support; names in plaintext Isar; key in OS secure storage **not** derived from password; plaintext appears only in temp/Mihon/Yomikiru paths.

5. **Mihon/Yomikiru:** decrypt chapter to `%TEMP%\local_vault_yomikiru\...` or `/storage/emulated/0/Manga/LocalVault/manga_temp/...`. Dialog Clean Up deletes that folder. **Switch apps:** dialog remains if the process lives; **if the OS kills the app, the option is gone.** Windows top-bar Clear temp **does** remove Yomikiru temp. Android top-bar Clear temp **does not** remove Mihon `Manga/LocalVault` dumps.

6. **Clear temp** does **not** delete `vault_blobs` or Isar. It targets app temp/cache and name-matched dirs under OS/app temp. It should **not** touch DCIM/Downloads. Tightening to an **allowlist of folders this app created** is the plan improvement; today the Mihon shared-storage dump is the main leftover, not a wipe of other user files.
