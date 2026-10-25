# Local Vault — Architecture & Design Analysis

**App version analyzed:** 2.5.2+6  
**Platforms:** Windows (desktop), Android (mobile)  
**Stack:** Flutter / Dart 3.2+, Isar, PointyCastle/encrypt, flutter_secure_storage  
**Analysis date:** 2026-03-13  

This document describes the **current** folder layout, architecture, design choices, libraries, product goals, and real performance characteristics for both platforms. It is based on the source tree as it exists today—not marketing claims alone.

---

## 1. Product goal and problem statement

### 1.1 Why the app exists

Local Vault targets users who want:

1. **Private local storage** for sensitive media (manga chapters, photos, videos, documents).
2. **No cloud / no account** — data never leaves the device unless the user exports it.
3. **AES encryption at rest** so files on disk are not readable as plain media.
4. **Manga-reader handoff** — decrypt into a temp tree and open in Yomikiru (Windows) or Mihon/Tachiyomi-class apps (Android).
5. **Bulk import** from folders and ZIP archives with folder structure preserved.

### 1.2 Problem it solves

| Problem | Intended solution |
|--------|-------------------|
| Sensitive media sits as plain files in gallery / Downloads | Encrypt into opaque `.bin` blobs under app storage |
| Cloud “private” vaults still involve vendors / sync | 100% offline, local-only vault |
| Manga libraries are large folder trees | Recursive folder / ZIP import + natural sort |
| Readers need plaintext pages | Controlled decrypt-to-temp + external open + manual cleanup |

### 1.3 Does v2.5.2 actually deliver this?

| Goal | Status | Notes |
|------|--------|-------|
| Local-only encrypted media vault | **Mostly yes** | Blobs on disk are AES-encrypted; app works offline |
| Master-password gate | **Yes, with caveats** | Password verified via PBKDF2; see security note below |
| Folder organization + search | **Yes** | Nested folders, natural sort, name search |
| Bulk folder / ZIP import | **Partial** | Works, but slow and memory-heavy; mobile folder UX is multi-file pick, not true directory pick |
| Manga reader export | **Yes** | Yomikiru / Android manga services exist and decrypt to temp |
| “Encrypted file names” (README) | **No** | `VaultFile.originalName` is stored **plaintext** in Isar |
| “Military-grade” / hardware AES | **Marketing overstatement** | Crypto is **pure Dart PointyCastle**, not AES-NI / OpenSSL / BCrypt |
| Smooth 50–100 files/sec import | **Unlikely on target devices** | Main-isolate PointyCastle + sequential encrypt; see §7 |
| Peak ~300 MB memory | **Not guaranteed** | ZIP import uses full `readAsBytes()`; container encrypt loads whole TAR |

**Security architecture note (important):**  
The password is an **app unlock gate**. The AES master key is stored separately in `flutter_secure_storage` as `master_key_b64` and is **not wrapped by the password**. Resetting the password keeps the same master key (`AuthService.resetPassword`). Anyone who can read the secure-storage dump (or a rooted/compromised OS session with vault access) can decrypt blobs without knowing the password. This is still useful as UI lock + OS keystore protection, but it is **not** classic password-derived vault encryption (VeraCrypt / age / SQLCipher-style).

---

## 2. Repository folder structure

```
local_vault/
├── lib/                          # All Dart application code
│   ├── main.dart                 # Entry: bindings, FVP (Windows), Isar open, runApp
│   ├── app/app.dart              # MaterialApp + lifecycle observer → AuthGate
│   ├── db/isar_db.dart           # Isar singleton open
│   ├── models/                   # Isar collections (+ generated *.g.dart)
│   │   ├── vault_file.dart
│   │   ├── vault_folder.dart
│   │   ├── app_settings.dart
│   │   └── file_tag.dart         # Schema exists; tagging not fully wired end-to-end
│   ├── services/                 # Business logic (large, overlapping surface)
│   ├── ui/
│   │   ├── auth/                 # Setup / login / recovery / AuthGate
│   │   ├── home/home_screen.dart # Windows desktop UI (~2550 LOC)
│   │   ├── mobile/mobile_home_screen.dart  # Android UI (~2130 LOC)
│   │   ├── viewers/              # Image / video viewers
│   │   ├── search/, settings/, pickers/, widgets/
│   ├── utils/vault_format.dart
│   ├── fvp_stub.dart / fvp_real.dart  # Conditional FVP for Windows video
│   └── ...
├── android/                      # Gradle + Kotlin MainActivity (FileProvider open)
├── windows/                      # Win32 runner + CMake
├── test/                         # Limited widget / integration tests
├── pubspec.yaml                  # Dependencies + Inno Setup / MSIX config
├── build_android.bat / build_windows.bat
├── README.md, GUIDE.md, DEVELOPMENT.md, CHANGELOG.md
└── (build artifacts under android/build — should stay gitignored)
```

### 2.1 What lives where (intent)

| Area | Responsibility |
|------|----------------|
| `lib/ui/*` | Screens, dialogs, navigation; currently also owns import/export orchestration |
| `lib/services/*` | Crypto, DB repository, import/export, manga open, “phase 2” perf helpers |
| `lib/models/*` | Isar schema only (no rich domain entities) |
| `lib/db/*` | Open Isar once at startup |
| `android/` / `windows/` | Platform runners + FileProvider / installer packaging |

There is **no** formal clean architecture (`domain/`, `data/`, `presentation/`), no state-management package (Provider/Riverpod/Bloc), and no single import/export pipeline. UI screens construct services directly.

---

## 3. Runtime architecture (how the app boots and runs)

```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()
  ├─ registerFvp()                 # Windows only (if enabled)
  ├─ HardwareAccelerationService   # Detects CPU flags; does not change crypto path
  ├─ MemoryManagementService       # Tweaks imageCache sizes
  ├─ PaintingBinding.imageCache    # Cleared + size capped
  ├─ IsarDb.open()                 # Support dir + vault_blobs/
  └─ runApp(VaultApp)
        └─ AuthGate
              ├─ SetupScreen       # first run: password + security Qs
              ├─ LoginScreen       # unlock
              └─ HomeScreen | MobileHomeScreen
```

### 3.1 Platform UI split

`AuthGate._getHomeScreen()`:

- **Android** → `MobileHomeScreen` (touch-first, SAF-oriented ZIP, multi-file “folder” import)
- **Windows / others** → `HomeScreen` (menus, true folder path import via `BulkImportService`, export ZIP)

Both screens are **monolithic StatefulWidgets** that embed repository, crypto, import, export, and manga flows. That makes platform parity hard and thrashing of performance logic likely.

### 3.2 Data model (Isar)

| Collection | Role |
|------------|------|
| `VaultFolder` | Tree via `parentId` |
| `VaultFile` | Metadata: `originalName`, `storedBlobName`, `ivBase64`, `byteSize`, `mimeType`, `sortOrder` |
| `AppSettings` | e.g. `maxStorageBytes` |
| `FileTag` / assignments | Defined; search/tag UX is incomplete vs README Advanced Search story |

**On-disk layout:**

- Isar DB under application support directory  
- Encrypted payloads under `vault_blobs/<random>.bin` (and optional `*.vault_container` for container strategy)

**Invariant:** DB metadata is plaintext; only blob bytes are encrypted.

---

## 4. Core flows — how things work

### 4.1 Authentication / unlock

1. `SecureStorageService.hasPassword()` → setup vs login.
2. Setup stores password PBKDF2-SHA256 hash (**120,000 iterations**, PointyCastle) + salt; creates random 32-byte master key if missing.
3. Unlock: `LoginScreen` → `AuthService.verifyPassword` → `SecureStorageService.verifyPassword`.
4. Failed attempts escalate lockout (5→30s, 8→2m, 10+→5m).
5. Security questions use salted SHA-256 (not PBKDF2).
6. On success, Navigator replaces with home screen (session is in-memory UI state only—no explicit vault session object).

**Performance implication:** PBKDF2 runs **synchronously on the calling isolate** (UI isolate). PointyCastle PBKDF2 at 120k iters is intentionally slow and feels laggy on mid-range phones.

### 4.2 Encrypt a single file (hot path for almost everything)

`VaultRepository.addMedia`:

1. Optional storage-limit check (loads **all** files to sum sizes — O(n) memory/CPU).
2. Load master key from secure storage.
3. `FileCryptoService.encryptFileToBlob` — stream AES-256-CTR (SIC) via PointyCastle `SICStreamCipher(AESEngine())`, write to `vault_blobs/*.bin`.
4. Insert `VaultFile` row in Isar.

Streaming avoids loading whole videos for the **individual** path—good design. Throughput is still limited by **software AES in Dart on the UI isolate**.

Alternate path `encryptAndWriteBlob` uses package `encrypt` (CBC-style helper) for in-memory bytes — used when `bytes` are passed instead of a path.

### 4.3 Import (multiple overlapping implementations)

| Path | Used by | Behavior |
|------|---------|----------|
| `BulkImportService.importFolder` | **Desktop** `HomeScreen` | Walk folder, **images only**, batch size 3, calls `repo.addMedia` (TODO isolate never done) |
| `UnifiedImportService` + `EnhancedVaultRepository` | **Mobile** folder multi-pick | Strategy: individual / container / hybrid |
| `ImportExportService.importFromZip` | Desktop ZIP + mobile fallback | **Whole ZIP into RAM** (`readAsBytes`), decode, extract to docs dir, then encrypt each file |
| `SafZipImportService` | Mobile Android preferred | SAF/URI oriented; still can fall into full-byte reads |

**Container strategy** (`FolderCryptoService`): copy files → TAR in memory → encrypt entire archive → one blob. Marketed as “70–85% faster”; on large libraries it **spikes RAM** and still uses Dart crypto.

### 4.4 Export

`ImportExportService.exportAllToZip` / `exportFolderToZip`:

1. Create temp staging directory.
2. For **each** file: `decryptBlobToFile` (PointyCastle stream on caller isolate).
3. Zip the staging tree (`ZipFileEncoder`, optional password).
4. Delete staging.

Cost ≈ **full vault decrypt I/O + ZIP compression + temp disk**. No worker pool; no direct stream-into-zip.

Standalone `ExportService` is a thin ZIP scaffold; real export lives in `ImportExportService`.

### 4.5 Open / view / manga

- Images: decrypt then viewer widgets (`OptimizedImageViewer`, progressive helpers).
- Video: `video_player`; Windows may use FVP when dependency enabled (currently commented in `pubspec.yaml`).
- Manga: `YomikiruIntegrationService` / `AndroidMangaService` decrypt tree to temp, launch external app, user cleans temp later.

### 4.6 Lifecycle / temp cleanup

`AppLifecycleService` + `VaultApp` observer attempt cleanup on pause/dispose. Temp plaintext during export/manga is a deliberate tradeoff (README acknowledges manual cleanup to avoid data loss).

---

## 5. Libraries and what they are used for

| Library | Role in Local Vault |
|---------|---------------------|
| **flutter** | UI + platform embedding |
| **isar** + **isar_flutter_libs** + **isar_generator** | Local metadata DB |
| **flutter_secure_storage** | Password hash, salt, iterations, master key, lockout counters, security Qs |
| **pointycastle** | PBKDF2, AES-CTR (SIC) engines for file crypto |
| **encrypt** | Higher-level AES helpers for in-memory encrypt/decrypt |
| **crypto** | SHA-256 (security questions, checksums) |
| **archive** | ZIP/TAR encode/decode for import/export/containers |
| **file_picker** | Pick files / save export path |
| **path_provider** / **path** | App dirs, path joins |
| **video_player** (+ optional **fvp**) | Video playback |
| **permission_handler**, **share_plus**, **url_launcher**, **device_info_plus**, **package_info_plus** | Android permissions, share/open, device metadata |
| **uri_content** | Android SAF / content URI reads |
| **msix** / **inno_bundle** (dev) | Windows packaging (Inno preferred over MSIX sandbox) |

**Not present (but typical for modern vault apps):** native crypto FFI (OpenSSL/BCrypt/Android Keystore Cipher), Riverpod/Bloc, workmanager, sqflite/drift alternatives, isolate pools wired into production import.

---

## 6. Desktop vs mobile design differences

| Concern | Windows (`HomeScreen`) | Android (`MobileHomeScreen`) |
|---------|------------------------|------------------------------|
| Navigation | Desktop menus / context menus | FAB / bottom actions / dialogs |
| Folder import | Real directory path via `BulkImportService` | Multi-select files + reconstruct structure |
| ZIP import | `ImportExportService` | Prefer SAF → fallback legacy |
| Export | Full vault / folder ZIP | More limited; manga-oriented flows |
| Video accel | FVP optional | System / ExoPlayer via `video_player` |
| Storage permissions | User-chosen paths | SAF + broad storage permissions in manifest |
| Perf helpers | Mostly unused stubs | `EnhancedVaultRepository` plugs thermal/battery/memory services (mostly placeholders) |

Shared core: same Isar schema, same `FileCryptoService`, same master-key model.

---

## 7. Performance aspect (both platforms)

### 7.1 What the code optimizes for (real)

**Good decisions already present:**

- Streaming encrypt/decrypt for single files (`openRead` / `openWrite` + CTR).
- `file_picker` with `withData: false` for large picks.
- Image cache caps (30–100 MB depending on platform).
- Batch Isar `putAll` helper exists for imports that use it.
- Natural sort after query (correctness for manga folders).

**What dominates wall-clock time today:**

1. **Pure Dart AES (PointyCastle)** — typically ~5–40 MB/s depending on device/mode; native AES is often **10–100×** faster (community measurements: Dart GCM ~seconds vs native ~tens of ms for multi‑MB payloads).
2. **Work on the UI isolate** — progress UI janks; password unlock freezes briefly.
3. **ZIP `readAsBytes()`** — RAM ≈ ZIP size; on 6 GB phones, large archives compete with OS + Flutter.
4. **Export staging** — decrypt entire selection to disk, then zip (2× write amplification).
5. **Artificial delays** — `Future.delayed(10–100ms)` between batches (BulkImport, MemoryManagement, IsolateEncryption progress fake-out).
6. **Storage limit check** — loads all `VaultFile` records to sum sizes on every add.
7. **“Hardware acceleration”** — detects AES-NI / NEON but **never switches** the cipher implementation.

### 7.2 Windows — Infinix GT Book class (i5-12450H, 16 GB, RTX 3050)

| Workload | Expected behavior today | Bottleneck |
|----------|-------------------------|------------|
| Password unlock | Noticeable pause (hundreds of ms–~1–2s) | PointyCastle PBKDF2 120k on UI isolate |
| Import 500 small images | Minutes, UI may stutter | Sequential Dart AES + Isar writes |
| Import large ZIP (1+ GB) | High RAM + slow | Full ZIP in memory + re-encrypt |
| Export large vault | Long + heavy disk use | Decrypt-all staging + zip |
| Video playback | OK if FVP enabled; software decode otherwise | GPU underused for crypto (crypto never hits AES-NI) |

The i5-12450H **has AES-NI**; the app does not use it. CPU and SSD are capable of much higher throughput with native streaming crypto + worker isolates.

### 7.3 Android — iQOO Z9x class (Snapdragon 6 Gen 1, 6 GB, 128 GB)

| Workload | Expected behavior today | Bottleneck |
|----------|-------------------------|------------|
| Password unlock | Often feels “stuck” 0.5–3s | PBKDF2 on UI + slower Dart |
| Folder multi-import | Thermal soak, frame drops | Main-isolate AES; thermal channel **unimplemented** in `MainActivity` |
| Password ZIP import | OOM risk / kill | Full archive in RAM |
| Container encrypt | Can peak >> 1 GB | Whole TAR + ciphertext in memory |
| Manga decrypt export | Slow but usable for moderate chapters | Sequential decrypt |

6 GB RAM shared with system: **streaming + bounded buffers** is mandatory; current ZIP/container paths violate that.

### 7.4 “Phase 2” performance services — design vs reality

| Service | Claimed role | Actual effect |
|---------|--------------|---------------|
| `HardwareAccelerationService` | Use AES-NI / NEON | Detection only; multipliers unused by crypto |
| `MemoryManagementService` | Adaptive batches / GC | Heuristics hardcoded; fake GC via dummy lists |
| `ThermalProtectionService` | Throttle on heat | MethodChannel `thermal_protection` **not** in `MainActivity`; fallback heuristics |
| `BatteryAwarenessService` | Adapt to battery | Returns **hardcoded** 70% / not charging |
| `IsolateCryptoService` | Offload crypto | **Placeholder** (returns input as “encrypted”) |
| `IsolateEncryptionService` | `compute()` bulk encrypt | Implemented but **not used** by UI import paths |
| `ProgressiveLoadingService` | Smooth image lists | Partially useful for viewers; not the import bottleneck |

These layers add complexity and sometimes **extra delays**, without fixing the root cost (Dart AES on the wrong isolate / wrong API).

### 7.5 Honest performance summary

Local Vault’s architecture is a **correct local encrypted file manager prototype** with strong product intent, but performance is constrained by:

- Software crypto instead of native AES  
- UI-isolate CPU work for unlock / encrypt / decrypt  
- Whole-archive memory patterns for ZIP/container  
- Monolithic screens with duplicated import stacks  
- Unfinished isolate/native acceleration layers  

On the stated benchmark devices, **browsing small unlocked libraries can feel fine**; **import, export, and unlock** are the pain points—and that matches the code paths above.

---

## 8. Design patterns currently in use

- **Service locator / singleton** — `SecureStorageService.instance`, thermal/memory/hardware singletons  
- **Repository** — `VaultRepository` (+ subclass `EnhancedVaultRepository`)  
- **Platform branching** — AuthGate + conditional FVP imports  
- **Strategy enum** — `EncryptionStrategy` (individual/container/hybrid)  
- **Scaffold / stub services** — export, isolate crypto, battery, hardware “optimize”  

Missing patterns that similar modern apps use successfully:

- Long-lived **crypto worker isolate** with chunked `TransferableTypedData`  
- **Native AES** (OpenSSL / BCrypt / Android `Cipher`) for streaming files  
- **Password-wrapped DEK** (KEK from Argon2id/PBKDF2)  
- Thin UI + ViewModel/Cubit with cancelable operations and real progress ports  
- Single **ImportPipeline** / **ExportPipeline** shared by both platforms  

See `BUGS_PERFORMANCE_AND_IMPROVEMENTS.md` for concrete defects and a target architecture sized for the GT Book and Z9x.

---

## 9. Related docs

| File | Purpose |
|------|---------|
| `BUGS_PERFORMANCE_AND_IMPROVEMENTS.md` | Architecture/implementation bugs, root-cause of slowness, target design |
| `DEV_SETUP.md` | Minimal PC setup to build Windows + Android again |
| `README.md` / `GUIDE.md` | User-facing overview and usage |
| `DEVELOPMENT.md` | Longer build/workflow notes (overlaps setup) |
