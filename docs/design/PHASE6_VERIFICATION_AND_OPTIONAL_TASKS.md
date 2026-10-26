# Phase 6 — code re-verification, devices, and dropped “optional” work

**Date:** 2026-10-26  
**Tree:** Local Vault 2.5.2+6 (Phases 0–5 in code; Phase 6 **not** implemented yet)  
**Devices:** Infinix GT Book (Windows, i5-12450H, 16 GB, NVMe) · iQOO Z9x (Snapdragon 6 Gen 1, 6 GB, UFS 2.2)

This is a **read of the current code** against `.kiro/specs/local-vault-redesign/tasks.md` Phase 6. It does not change production behavior. Companion: `PROCESS_BOTTLENECKS_AND_PHASE6_ARCHITECTURE.md`, `THEME_DARK_LIGHT_IMPLEMENTATION.md`.

---

## 1. Will Phase 6 break the current vault?

**No, if each task stays inside its listed files and the hard constraints are obeyed.** Import/export speed the user already likes lives in:

- `NativeCryptoEngine` (BCrypt / javax.crypto, 512 KB chunks)
- `JobRunner` **one item at a time** (`for (final item in items)` in `lib/app/job_runner.dart`)
- Streaming ZIP **import** (`ArchiveReader` + temp + encrypt + delete plaintext)
- Isar + `BlobStore` atomic rename

None of 6.1–6.9 require changing that hot path except **6.1**, which moves **ZIP encode** (export only, Windows) off the UI isolate. Decrypt still happens one file → one temp, same as today.

| Task | Touches hot path? | Break risk | GT Book | Z9x |
|------|-------------------|------------|---------|-----|
| 6.1 ZIP worker + STORE | Export ZIP encode only | Low if worker owns `ZipFileEncoder` for the whole job (no `readAsBytes`) | **Yes — this is the jitter fix.** Extra Dart isolate ~few MB. STORE **reduces** CPU vs DEFLATE-on-JPEG. | Export is **Windows-only**. Phone **does not run 6.1**. No extra isolate on Android. |
| 6.2 Change password UI | `AuthSession.changePassword` (already exists) | Low. PBKDF2 already in `Isolate.run`. | Fine (~100–200 ms KDF × 2). | Fine (~0.5–1 s KDF × 2). UI spinner must stay. |
| 6.3 Resume | `app.dart` + existing `JobRunner` | **Medium if ZIP jobs call `JobRunner` blindly.** ZIP items are created `running`, so `findPendingItems` skips them. Implementer **must** branch folder vs ZIP as tasks.md says. Discard path must stay identical. | Fine. | Fine; this is the 1–2 GB phone-import value. |
| 6.4 Rollback marker | Secure storage + dialog | Low. No blobs. | Fine. | Fine. |
| 6.5 Delete deprecated | Dead services | Medium only if a forgotten import remains. Grep + `flutter analyze` gate. | Smaller binary. | Smaller APK. |
| 6.6 Opt-in v0→v1 | Per-file decrypt/encrypt | Medium if made automatic. Keep opt-in, per-file commit. | Fast (AES-NI). | Slower (minutes on a mixed vault); must pause in background. Fresh v1 vaults: **empty work**. |
| 6.7 Theme | `VaultApp` + Settings + greys | **UI-only.** Wrong hardcoded colors = unreadable text, not data loss. Follow the theme spec. | Fine. | Fine. Dark is slightly cheaper on OLED-ish panels; Z9x LCD/AMOLED difference is negligible vs AES. |
| 6.8 Progress chrome | Dialogs + Settings | Low. Coalesce `setState` **reduces** rebuilds. | Smoother spinner. | Smoother spinner; no extra I/O. |
| 6.9 FLAG_SECURE | Android window flag | Low if default **off**. | No-op. | Toggle on blocks recents/screenshots; unlock still works. |

**Merge conflicts (process, not runtime):** `app.dart` is shared by 6.3, 6.4, 6.7. `settings_screen.dart` is shared by 6.2, 6.7, 6.8, 6.9. `AppSettings` + `build_runner` shared by 6.7 and 6.9. Implement in the order in tasks.md; regenerate Isar **once** if both fields land together.

**What would actually break devices if someone “improves” Phase 6:**

- Parallel `JobRunner` workers → thermal pause fights itself on Z9x; MethodChannel contention; two plaintexts on disk.
- `Isolate.run` + `readAsBytes` for ZIP export → RAM spike; 6 GB phone / large video = OOM risk (export is Windows-only today, but do not copy that pattern).
- archive 4 / `zcodec` → API rename landmine, new dependency (forbidden).
- Riverpod rewrite of god screens → high regression, zero MB/s.
- Filename encryption → search/index rewrite (see §3).

---

## 2. Device fit (will it run smoothly?)

### Infinix GT Book

Already runs the October 2026 pipeline at ~750 MB / 224 images in ~10–15 s import, ~30 s export with a **jittery** spinner. Phase 6:

- 6.1 is the smoothness fix: ZIP work leaves the UI isolate so the spinner can hold ~60 fps. STORE skips wasted JPEG DEFLATE (the 5–15 ms per file that drops frames). Wall-clock export likely **same or a few seconds faster**, not a new bottleneck.
- One extra isolate is trivial on 16 GB / 8+8 cores.
- Theme, settings, resume dialogs: idle CPU.

**Verdict:** Phase 6 as written is appropriate and should feel **smoother**, not heavier.

### iQOO Z9x

Import ~20–30 s for the same 750 MB ZIP, **no** export path. 6 GB RAM; UFS 2.2; thermal monitor already pauses encrypt at MODERATE (does not skip files).

- 6.1: **does not run** (no Windows ZIP export).
- 6.7 / 6.8: paint and one extra Isar field. No AES change.
- 6.2: one-off KDF ~0.5–1 s, already isolated.
- 6.3: resume avoids re-encrypting committed files — **saves** work after a kill.
- 6.6: only if old v0 blobs exist; sequential re-encrypt; keep it opt-in so a 2 GB mixed vault does not surprise-heat the phone.

**Verdict:** Phase 6 will run smoothly if parallelism and archive upgrades stay out. Do not raise `JobRunner` concurrency “because the PC has cores.”

---

## 3. Dropped optional work — what it is, value, cost

These were **removed** from Phase 6 on purpose. Do not implement them in the 6.1–6.9 pass.

### 3.1 Filename encryption

**What it would do:** `VaultFile.originalName` (and folder names) are **plaintext in Isar** today. Blob files on disk are already random `uuid.bin`. Filename encryption would wrap display names with the DEK (or an HMAC-index) so a copied `local_vault.isar` would not show manga/photo titles.

**Is it a good idea for this app?** **Weak yes for threat-model completeness, no for Phase 6 / daily use.**

- Attacker who already has the unlocked session sees names anyway.
- Attacker with the phone but **no** password already cannot decrypt blobs. They **can** read titles, sizes, folder tree — metadata leak. Real, but secondary.
- Cryptomator encrypts names because the vault is often on **cloud sync**. This product is **local-only**. The extra threat is “someone dumps the app-support folder,” not Dropbox listing.

**Performance / bottlenecks:**

| Operation | Today | With encrypted names (typical design) |
|-----------|--------|----------------------------------------|
| Open folder (list) | Isar query, names as stored | Decrypt N names in RAM after unlock, **or** maintain a session cache. First paint: ~1–5 ms extra on GT Book for a few hundred files; ~5–20 ms on Z9x. Fine. |
| Search by name | Isar prefix / contains on `originalName` | **Broken** unless you add a searchable HMAC/trigram index. Naive decrypt-all-then-filter: thousands of files → tens to hundreds of ms on Z9x, plus no index. That **is** a bottleneck. |
| Import | Write plaintext name + encrypt blob | Extra AES-GCM on a short string: **microseconds**. Not the 10–30 s import. |

**RAM:** a decrypted name cache for 10k files is a few MB. Not the problem. **Search architecture** is the problem.

**Devices:** would **run**, but search would feel worse on Z9x unless you invest in a proper encrypted index (scope of a major version, not a polish task).

**Recommendation:** keep UUID blob names (already done). Leave Isar names plaintext. Revisit only if the vault directory is ever synced or backed up to a third party.

---

### 3.2 Riverpod (and why it was dropped)

**What Riverpod is:** a Flutter **reactive state / DI** library. You declare `Provider`s; widgets `ref.watch` them and rebuild when data changes. It is **not** a crypto engine, **not** an import worker, and **not** a performance feature by itself.

**What people hope it would do here:** split the 3.2k-line `home_screen.dart` and 2.2k-line `mobile_home_screen.dart` so import progress, folder path, and multi-select are not giant `setState` blobs.

**Actual value for the user:** **none visible.** Import/export already run in coordinators + native code. The UI `setState` per file is a **frame** cost, which 6.8’s coalescer fixes in ~20 lines without a new package (Phase 6 forbids new pub dependencies anyway).

**Cost / overhead:**

- CPU/RAM of Riverpod itself: **negligible** (a map of listeners). Not seconds of import, not hundreds of MB.
- **Engineering cost:** rewrite both god screens, AuthGate, Settings, every dialog that today constructs `ImportCoordinator` directly. High chance of breaking Resume, thermal pause, or picker flows. Weeks of work, zero MB/s.

**Devices:** would run fine **after** a correct rewrite. The danger is the rewrite, not the library.

**Recommendation:** stay on constructor-injected services + `setState` / a tiny `ValueNotifier` for theme (6.7). Revisit Riverpod only as a future major version if you are splitting desktop/mobile shells on purpose.

---

### 3.3 Parallel import workers

**What it would do:** `JobRunner` currently encrypts **one file after another**. Parallel workers (e.g. 2) would encrypt two blobs at once (two MethodChannel calls, two native AES jobs, two `.partial` files).

**What it does *not* do:** make AES faster per byte. Native AES-GCM on GT Book is already AES-NI-bound and finishes a 3 MB JPEG in **&lt;1 ms**. The 10–15 s import is **files × (open + encrypt + rename + Isar)**. Parallelism only overlaps the sequential waiting.

**Optimistic wall-clock (same 750 MB / 224 images):**

| Device | Today (1 worker) | Hypothetical 2 workers | Why it may not show up |
|--------|------------------|------------------------|------------------------|
| GT Book | ~10–15 s | ~7–12 s if disk + channel keep up | NVMe can take two streams; MethodChannel and Isar writes still serialize some work. Best case **a few seconds**, not 2×. |
| Z9x | ~20–30 s | **Unreliable.** Thermal MODERATE pause was built for **one** encrypt. Two AES + UFS 2.2 random writes → heat, jank, possible **slower** total if pause fires more often. Extra ~1 MB buffers; two large videos would be the RAM worry, not two JPEGs. | |

**Overhead:** extra isolate/threads, two partial blobs, harder crash-resume (which item is in flight?), progress dialog races. **User already calls import “instant.”** Tasks.md: *No JobRunner parallelism change.*

**Recommendation:** do not add this in Phase 6 or as a silent “optimization.” If ever: desktop-only cap of 2, Android stay at 1, and measure thermal on Z9x before shipping.

---

## 4. Summary for the next implementer

1. Implement 6.1–6.9 as specified; **do not** sneak in filename encryption, Riverpod, or parallel workers.
2. For 6.7, follow `THEME_DARK_LIGHT_IMPLEMENTATION.md` only.
3. After each task: vault health check + a small import on **both** devices (export on GT Book only).
4. If a task threatens import MB/s, revert **that** task only.
