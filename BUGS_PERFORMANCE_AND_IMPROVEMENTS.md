# Bugs, Performance Root Causes & Target Architecture

**App:** Local Vault 2.5.2+6  
**Benchmark devices (must feel smooth):**

| Device | Specs |
|--------|--------|
| **Laptop** | Infinix GT Book — Intel i5-12450H, 16 GB RAM, 512 GB SSD, RTX 3050 6 GB (80 W) |
| **Phone** | iQOO Z9x — Snapdragon 6 Gen 1, 6 GB RAM, 128 GB storage |

This document pinpoints **architecture / design bugs**, **implementation bugs**, explains **why unlock / import / export feel slow**, and proposes a **concrete better architecture** tuned for those devices. Findings come from static analysis of the current codebase plus industry patterns for Flutter client-side encryption (streaming + isolates + native AES).

Companion doc: [`ARCHITECTURE_AND_DESIGN.md`](ARCHITECTURE_AND_DESIGN.md).

---

## 1. Architecture & design bugs

### A1. Password gate ≠ cryptographic vault unlock

**Where:** `SecureStorageService.getOrCreateMasterKey32`, `AuthService.resetPassword`  
**Bug:** Master AES key is stored independently of the password. Password reset keeps the same DEK.  
**Impact:** Password only protects the UI (plus OS secure storage). Design docs / README imply password-protected encryption.  
**Fix direction:** Derive a KEK from password (Argon2id or PBKDF2), wrap DEK; unwrap on unlock; store only wrapped DEK + salt/params.

### A2. Overlapping import/export stacks (no single pipeline)

**Where:** `BulkImportService`, `UnifiedImportService`, `ImportExportService`, `SafZipImportService`, `EnhancedVaultRepository`, unused `IsolateEncryptionService`, scaffold `ExportService`  
**Bug:** Same product feature implemented 4+ ways with different capabilities (desktop images-only folder import vs mobile multi-pick vs ZIP memory decode).  
**Impact:** Bugs fixed in one path remain in others; performance work never lands in the hot path users actually hit.

### A3. God UI layer

**Where:** `home_screen.dart` (~2550 LOC), `mobile_home_screen.dart` (~2130 LOC)  
**Bug:** Screens own picking, progress dialogs, repository calls, manga export, settings hooks.  
**Impact:** Hard to move crypto off UI isolate, hard to cancel jobs, hard to share logic across platforms, hard to test.

### A4. “Performance services” are architectural theater

**Where:** `HardwareAccelerationService`, `MemoryManagementService`, `ThermalProtectionService`, `BatteryAwarenessService`, `IsolateCryptoService`  
**Bug:** They sit in the design as Phase-2 optimization but do not change the cipher, do not measure real memory, do not talk to real thermal/battery APIs, or (for isolate crypto) do not encrypt at all.  
**Impact:** False confidence (“hardware accelerated import”) while users still suffer Dart AES on the main isolate. Extra `Future.delayed` calls can **slow** imports further.

### A5. Metadata privacy mismatch

**Where:** `VaultFile.originalName` plaintext; README claims encrypted names  
**Bug:** Design claim ≠ data model.  
**Impact:** Folder structure / titles readable if DB is copied; undermines “complete privacy” positioning.

### A6. Container encryption strategy fights the device model

**Where:** `FolderCryptoService.createEncryptedContainer`  
**Bug:** Builds a full TAR in memory, encrypts whole buffer, writes one blob; extract decrypts **entire** container to get one file.  
**Impact:** Catastrophic on 6 GB phones for manga libraries; random access is O(full container). Individual encrypted blobs + index is the right design for media vaults.

### A7. No cancelable, priority-aware job system

**Bug:** Long imports/exports are fire-and-forget Futures from dialogs; no shared job queue, no pause on thermal, no resume.  
**Impact:** Users force-kill the app; partial imports leave orphan blobs / inconsistent DB.

### A8. Dual crypto modes without clear policy

**Where:** Streaming CTR in `encryptFileToBlob` vs `encrypt` package path in `encryptAndWriteBlob` / folder container  
**Bug:** Two constructions, different memory profiles, unclear integrity (CTR without auth tag).  
**Impact:** Harder security review; container path loads all bytes; no AEAD.

---

## 2. Implementation bugs (concrete)

| ID | Location | Bug | Severity |
|----|----------|-----|----------|
| I1 | `isolate_crypto_service.dart` | Encrypt/decrypt/hash/compress are **placeholders** returning input / dummy data | Critical if ever wired |
| I2 | `bulk_import_service.dart` `_importFileWithIsolate` | Comment says isolate; still calls `repo.addMedia` on caller isolate; TODO never done | High (perf) |
| I3 | `IsolateEncryptionService` | Real `compute()` encrypt exists but **UI never uses it** | High (dead code) |
| I4 | `import_export_service.dart` `_extractZipManually` | `await zipFile.readAsBytes()` — entire ZIP in RAM; comment prefers this “for reliability” | Critical (OOM / jank) |
| I5 | `saf_zip_import_service.dart` | Same whole-file byte pattern in places | High |
| I6 | `folder_crypto_service.dart` | Full archive encrypt/decrypt in memory | Critical on mobile |
| I7 | `secure_storage_service.dart` `verifyPassword` | `_pbkdf2Sha256` is **sync** on UI isolate | High (unlock lag) |
| I8 | `MainActivity.kt` | Only `local_vault/file_opener`; **no** `thermal_protection` channel | Medium |
| I9 | `BatteryAwarenessService` | Hardcoded battery 70%, charging false | Medium (fake throttling) |
| I10 | `MemoryManagementService` | `_isMemoryPressureHigh` always false; `_isMemoryPressureLow` always true; “GC” allocates dummy lists | Medium |
| I11 | `HardwareAccelerationService` | Detects AES-NI then logs; crypto still PointyCastle | High (perf) |
| I12 | `VaultRepository.addMedia` storage limit | `findAll()` all files to sum sizes every import | Medium |
| I13 | `BulkImportService._getAllFiles` | Only image extensions — videos/docs silently skipped on desktop folder import | High (functional) |
| I14 | `EnhancedVaultRepository._addFilesIndividually` | On thermal pause returns `false` and **skips file** (data loss) instead of waiting/retrying | High |
| I15 | `isolate_crypto_service.dart` | Uses `Uint8List` without importing `dart:typed_data` (fragile / analyze risk) | Low–Med |
| I16 | Export staging | Decrypt all → zip → delete; no streaming into zip; no progress isolate | High (perf) |
| I17 | `FileTag` models | Present but not fully integrated; search claims overshoot implementation | Low |
| I18 | FVP in `pubspec.yaml` | Commented out; Windows hardware video path inconsistent with README | Medium |
| I19 | Artificial delays | 10–100 ms sleeps between batches in bulk/memory/isolate helpers | Medium (self-inflicted latency) |
| I20 | Password ZIP | archive package password ZIP + full decode — weak + heavy | Medium |

---

## 3. Why performance is bad (root cause analysis)

### 3.1 Password match on initial screen

**Call chain:**  
`LoginScreen._unlock` → `AuthService.verifyPassword` → `SecureStorageService.verifyPassword` → PointyCastle `PBKDF2KeyDerivator` **120,000** iterations, **synchronously**.

| Factor | Effect on GT Book | Effect on Z9x |
|--------|-------------------|---------------|
| PointyCastle PBKDF2 (pure Dart) | ~0.3–1.5 s typical | Often ~1–3+ s |
| Runs on UI isolate | Button spinner freezes / ANR-feel | Worse; main thread contested |
| Secure storage reads | Extra I/O before/after | Same |
| Lockout counters | More secure-storage writes on failure | Same |

**Not** “Flutter is slow.” It is **intentional KDF cost + software implementation + wrong isolate**.

**Modern fix:** Run KDF in `Isolate.run` / worker; prefer platform crypto (Android Keystore / Windows CNG); consider Argon2id with calibrated time (~250–400 ms) and cache unwrapped DEK in memory for the session.

### 3.2 Import slowness

**Dominant costs (ordered):**

1. **AES in PointyCastle on UI isolate** — community data: pure Dart often ~5–30 MB/s; native OpenSSL/BCrypt/Android Cipher commonly **>200 MB/s** and uses AES-NI / ARMv8 crypto (both benchmark CPUs have this).
2. **Per-file sequential pipeline** — encrypt → Isar txn → next; little parallelism even on 8+8 i5-12450H.
3. **ZIP path** — load entire archive → extract plaintext to disk → encrypt each file again (triple I/O for ZIP imports).
4. **Desktop bulk** — batch size 3 + 100 ms delay → artificial ceiling ~30 files/s **before** crypto cost.
5. **Mobile “optimizations”** — battery/thermal delays with fake sensors can add waits; container path can thrash 6 GB RAM.

**Why GT Book still feels slow:** AES-NI sits idle; one Dart isolate does software AES; SSD waits on CPU.  
**Why Z9x feels worse:** Weaker single-thread Dart crypto + thermal + RAM pressure + ZIP `readAsBytes`.

### 3.3 Export slowness

**Call chain:**  
For each file → `decryptBlobToFile` (Dart AES stream) → write plaintext staging → after all files → `ZipFileEncoder.addDirectory`.

| Cost | Description |
|------|-------------|
| CPU | Full vault decrypt in software AES |
| Disk | Write plaintext copy of entire selection, then read again for ZIP |
| RAM | ZIP encoder may buffer; password ZIP adds CPU |
| UI | Same isolate as progress dialog |

Expected: multi‑GB vaults take many minutes on Z9x; GT Book better but still CPU-bound until native crypto + parallel decrypt workers.

### 3.4 Rough throughput model (order-of-magnitude)

Assume PointyCastle CTR ≈ **15 MB/s** effective on Z9x, ≈ **40 MB/s** on GT Book (optimistic software). Native AES ≈ **300–1500+ MB/s**.

| Task | Z9x today (est.) | Z9x target | GT Book today (est.) | GT Book target |
|------|------------------|------------|----------------------|----------------|
| Unlock | 1–3 s | ≤ 400 ms | 0.3–1.5 s | ≤ 250 ms |
| Import 1 GB media | ~1–3+ min + jank | ~10–40 s smooth UI | ~30–90 s | ~5–20 s |
| Export 1 GB | ~2–5+ min | ~15–60 s | ~1–3 min | ~10–40 s |
| ZIP 500 MB import | High OOM risk | Stream, ≤ ~400 MB peak | Heavy RAM | Stream, bounded |

Targets assume: native streaming AES + worker isolate(s) + no full-archive RAM + batched DB writes + no fake delays.

---

## 4. Target architecture (good / “perfect enough”)

### 4.1 Layered structure

```
lib/
  app/                 # bootstrap, DI
  core/                # result types, logging, device profile
  domain/              # entities, repository interfaces, use cases
  data/
    isar/              # Isar DTOs + mappers
    crypto/            # NativeCryptoGateway + Dart fallback
    fs/                # blob store, temp, SAF
    secure/            # keystore / password wrap
  features/
    auth/
    browser/           # folder/file UI state
    import_export/     # single pipeline
    reader_bridge/     # Yomikiru / Mihon
  ui/                  # thin widgets only
```

**State:** Riverpod or Bloc — one `ImportJobController` / `ExportJobController` shared by desktop & mobile shells.

### 4.2 Crypto & security redesign

```
Password
   │  Argon2id / PBKDF2 (native, in background isolate)
   ▼
KEK  ──wrap/unwrap──►  DEK (32-byte AES key)
                          │
                          ▼
              Native AES-256-CTR or AES-256-GCM
              streaming 256KB–1MB chunks
              (OpenSSL / BCrypt / Android Cipher)
```

- Prefer **AES-GCM** (integrity) or CTR+HMAC if GCM streaming is awkward cross-platform.  
- Optional: encrypt filename into separate field; show decrypted names only in session.  
- Persist only: salt, KDF params, wrapped DEK, per-file IV/nonce + tag.

**Packages / approaches to evaluate:** FFI to OpenSSL on Windows+Android, or plugins in the spirit of native file AES (`aes_encrypt_file`, custom JNI/C++). Pure Dart remains fallback only.

### 4.3 Single Import / Export pipeline

```
ImportJob
  sources: FolderWalker | ZipStreamExtractor | SafUriSource
  stages:  enumerate → schedule → encryptChunk → writeBlob → batchUpsertIsar
  workers: 1–2 crypto workers (phone), 2–4 (laptop)
  policy:  DeviceProfile (RAM, cores, thermal)

ExportJob
  stages:  query tree → decryptStream → zipEntryStream → finalize
  never materialize full vault plaintext on disk if avoidable;
  if staging required (external reader), stream file-by-file with cap on concurrent plaintext files
```

**ZIP:** use streaming decode (`InputFileStream` / entry iterators); **never** `readAsBytes` for archives > ~32–64 MB.

**Cancel:** cooperative cancel token checked between files/chunks.

### 4.4 UI structure

- `DesktopShell` / `MobileShell` — layout only  
- Shared `VaultBrowserView` + controllers  
- Progress via message ports from worker (real % = bytes processed / total bytes)

### 4.5 What to delete or demote

| Keep / rewrite | Delete or quarantine |
|----------------|----------------------|
| `FileCryptoService` → rewrite as facade over native | `IsolateCryptoService` placeholders |
| One `VaultRepository` | Parallel `Enhanced*` until merged |
| Streaming blob store | In-memory container encrypt as default |
| Real device profile (cores, RAM class) | Fake battery 70%, fake memory pressure, unused multipliers |

---

## 5. Device-specific performance plan

### 5.1 Shared rules (both devices)

1. **Never** encrypt/decrypt/KDF on the UI isolate.  
2. **Never** load whole ZIP/TAR/video into a `Uint8List` for crypto.  
3. Chunk size **256 KB–1 MB**; max concurrent plaintext files **1–2** on phone, **2–4** on laptop.  
4. Batch Isar writes every N files (e.g. 25–50) in one transaction.  
5. Maintain running `totalBytesUsed` in `AppSettings` instead of scanning all rows.  
6. Progress = bytes, not “files with sleep”.  
7. Release builds only for benchmarking (`flutter run --release`).

### 5.2 Laptop — Infinix GT Book (i5-12450H, 16 GB, 3050)

| Area | Recommendation |
|------|----------------|
| Crypto workers | 2–4 long-lived isolates **or** native threads via FFI (prefer native AES-NI) |
| Import concurrency | 3–4 files if each ≤ 50 MB; 1 large video at a time |
| Export | Parallel decrypt 2–3 streams into zip writer with bounded queue |
| RAM budget | Allow ~1–2 GB peak for jobs; still stream |
| GPU | Keep FVP for video **playback** only; do not expect GPU to help AES unless using a GPU crypto API (not worth it—AES-NI is enough) |
| Thermal | Desktop can run full speed; optional pause if CPU package hot |
| Storage | Keep vault on SSD; avoid exporting to slow USB for benchmarks |

**Success criteria:** Unlock < 250 ms; import ~100–300+ MB/s native; UI stays ≥ 55 FPS during import.

### 5.3 Phone — iQOO Z9x (SD 6 Gen 1, 6 GB)

| Area | Recommendation |
|------|----------------|
| Crypto workers | **1** native stream (or 1 isolate + native); avoid 2+ heavy Dart isolates (RAM duplication) |
| Import concurrency | 1 file encrypt at a time for large media; small images can batch metadata |
| ZIP | Stream extract to temp **one entry at a time** → encrypt → delete plaintext entry |
| RAM hard cap | Peak job memory ≤ ~400–500 MB; refuse container-in-RAM strategy |
| Thermal | Implement real `PowerManager.getCurrentThermalStatus` in `MainActivity`; pause between chapters when ≥ moderate |
| Battery | Use `battery_plus` or OS APIs; reduce concurrency on battery < 20% |
| Storage | Prefer app-specific storage + SAF; avoid duplicating full libraries in cache |
| UI | Keep lists virtualized; decode thumbnails off main isolate; cap image cache ~20–30 MB |

**Success criteria:** Unlock ≤ 400 ms; no OOM on 500 MB ZIP; import UI remains interactive; sustained encrypt without thermal kill.

### 5.4 Task-level improvement checklist

**Unlock**

- [ ] Move PBKDF2/Argon2 to background isolate / native  
- [ ] Unwrap DEK once per session into memory; clear on lock/background  
- [ ] Optional biometric unlock caching wrapped key (Android Keystore / Windows Hello)

**Import folder**

- [ ] One walker for all media types (images **and** video/docs)  
- [ ] Native streaming encrypt per file  
- [ ] Batch DB inserts  
- [ ] Remove 100 ms artificial delays  
- [ ] Desktop: keep real directory pick; mobile: document tree SAF where possible

**Import ZIP**

- [ ] Streaming extractor  
- [ ] Password ZIP: consider decrypting with native libs or advise “import folder” for huge archives  
- [ ] Cap concurrent extracted plaintext

**Export**

- [ ] Stream decrypt → zip entry without full vault staging when possible  
- [ ] If staging needed for manga readers: decrypt chapter-sized batches, not entire library  
- [ ] Parallelism per DeviceProfile

**Browse / open**

- [ ] Decrypt on demand to temp with TTL cleanup  
- [ ] Thumbnail cache with size limit; regenerate from encrypted source

---

## 6. Suggested migration order (low risk → high impact)

1. **Quick wins (1–3 days)**  
   - Offload `verifyPassword` PBKDF2 to `Isolate.run`  
   - Remove artificial `Future.delayed` in import loops  
   - Fix storage quota to use cached total  
   - Stop skipping files on thermal; wait instead  
   - Desktop bulk: include non-image extensions  

2. **Structural (1–2 weeks)**  
   - Extract `ImportJob` / `ExportJob` from god screens  
   - Replace ZIP `readAsBytes` with streaming  
   - Wire **one** real background encrypt path (even Dart isolate streaming) into both UIs  

3. **Native crypto (2–4 weeks)**  
   - FFI/plugin AES-CTR/GCM file streaming on Android + Windows  
   - Password-wrapped DEK migration with versioned header  

4. **Polish**  
   - Real thermal/battery channels  
   - Delete stub services  
   - Encrypt names / optional DB encryption  
   - Integration tests for import cancel / OOM ceilings  

---

## 7. Verification plan on benchmark devices

| Test | Method | Pass |
|------|--------|------|
| Unlock latency | Stopwatch around `verifyPassword` in release | GT Book ≤ 250 ms; Z9x ≤ 400 ms |
| Import 1 GB folder | Wall time + `adb shell dumpsys meminfo` / Task Manager | No ANR; peak RSS within budgets above |
| Import 500 MB ZIP | Same | Completes without process kill |
| Export 1 GB | Wall time + free disk | Completes; UI responsive |
| Frame jank | Flutter DevTools performance | Import overlay does not freeze > 200 ms regularly |

Instrument with temporary NDJSON/timing logs around: KDF start/end, per-file encrypt MB/s, ZIP decode strategy, export decrypt MB/s. Compare before/after on **the same** GT Book and Z9x builds.

---

## 8. Bottom line

Local Vault’s **product idea is sound**; the **implementation architecture over-promises Phase-2 optimization** while the hot paths still use **software AES and whole-file ZIP loads on the UI isolate**. That is why unlock, import, and export feel bad even on an i5-12450H laptop and especially on a 6 GB Snapdragon 6 Gen 1 phone.

The path to “runs smoothly on GT Book + Z9x” is not more placeholder services—it is **one streaming pipeline, native AES, background KDF, bounded memory, and thin UI**.
