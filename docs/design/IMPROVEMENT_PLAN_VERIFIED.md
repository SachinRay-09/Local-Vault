# Verified Improvement Plan (Product-Safe)

**Status:** Reviewed against Flutter official architecture, OWASP crypto/password storage, NIST SP 800-132 (KEK/DEK envelope), Android Thermal / Keystore docs, and `Copilot_response.md`.  
**Product goal that must not break:** Store manga chapters (nested folders + images) encrypted at rest; unlock only with the user’s password; import smoothly on Windows and Android; **export folders/ZIPs on Windows only** so libraries can move PC → phone; open chapters in the app (and optional external readers).

This document **locks** what to keep, what to change, what must *not* be done in v1 of the rewrite, and why.

---

## Verdict

The earlier `BUGS_PERFORMANCE_AND_IMPROVEMENTS.md` diagnosis is **correct**. The Copilot response is the **better implementation blueprint** and should be preferred over a big-bang rewrite.

**Do this:** fewer pipelines, streaming I/O, jobs that commit per file, password-wrapped DEK *with migration*, native async AES later, thin shells.

**Do not do this in the first implementation pass:** encrypt every filename at once, re-encrypt the whole library, drop Flutter/Isar, invent a TAR-container format, skip files when the phone is hot, or ship native crypto before a versioned format + Windows/Android compatibility tests.

---

## Product invariants (must survive every change)

| Invariant | Why |
|-----------|-----|
| Nested folder tree + natural sort (`1`, `2`, `10`) | Manga chapter order |
| One encrypted blob per page/file | Open one page without decrypting the chapter archive |
| Import folder **and** ZIP on both platforms | How libraries enter the vault |
| Export folder / ZIP **Windows only** | User: “export is not needed in mobile”; PC → phone is export-on-PC, import-on-phone |
| Existing vaults keep working after upgrade | Password + blobs + Isar rows must migrate, not wipe |
| Wrong password never decrypts blobs | After KEK/DEK wrap; until then, document honest UI-gate + OS storage |
| Progress UI stays usable during import | Main isolate must not run bulk AES / ZIP decode |
| No silent skip of supported images | Thermal pause ≠ drop file |

**PC → phone flow to preserve:** Windows `Export folder/vault ZIP` (plaintext pages in ZIP for interchange) → Android `Import ZIP/folder` → re-encrypt into phone vault. Encrypted `.bin` portability across devices is a *later* optional goal, not required for this product flow.

---

## Trusted sources used

| Source | What it confirms |
|--------|------------------|
| [Flutter app architecture](https://docs.flutter.dev/app-architecture/guide) | UI (View + ViewModel) + Data (Repository + Service). Domain/use-case layer only if logic is complex. Lean widgets. |
| [Flutter architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) | Repositories as source of truth; do not put business logic in widgets. |
| [Flutter isolates](https://docs.flutter.dev/perf/isolates) | Offload work that misses frame budget. Isolates **copy** messages — do not ship giant `Uint8List`s between isolates. Prefer path-in / path-out native or long-lived workers. |
| [Flutter performance best practices](https://docs.flutter.dev/perf/best-practices) | Split god widgets; lazy lists; avoid `setState` at the root during import progress. |
| [OWASP Cryptographic Storage](https://cheatsheetseries.owasp.org/cheatsheets/Cryptographic_Storage_Cheat_Sheet.html) | AES-256 + authenticated mode (GCM); DEK wrapped by KEK; password-derived KEK so password change does not re-encrypt files. |
| [OWASP Password Storage](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) | Prefer Argon2id; if PBKDF2, HMAC-SHA-256; hash time typically **&lt; 1 s**; calibrate on device. |
| [NIST SP 800-132](https://csrc.nist.gov/pubs/sp/800/132/final) | Password → master key that **wraps data-protection keys** (exactly KEK/DEK). |
| [Android Keystore](https://developer.android.com/privacy-and-security/keystore) | Optional device-assisted wrap/recovery; **not** the bulk AES path for GB of manga. |
| [Android Thermal / PowerManager](https://developer.android.com/games/optimize/adpf/thermal) | `getCurrentThermalStatus` + listener; pause/slow work, do not discard items. |

---

## What Copilot adds (adopt)

These items from `Copilot_response.md` **improve** the first plan and reduce breakage:

1. **Keep Flutter and Isar.** The bottleneck is crypto/ZIP/UI orchestration, not the framework or DB.
2. **Keep individual blobs.** Drop in-memory TAR/container as a normal import strategy (it fights manga random access and 6 GB RAM).
3. **Two shells, one engine.** `DesktopShell` / `MobileShell` share import/browser/auth coordinators. Export coordinator is **Windows-only**.
4. **Do not create hundreds of use-case files.** Flutter’s own guide says a domain layer is optional. Split only at real boundaries: ViewModels, repositories, crypto engine, job runner, archive reader.
5. **Jobs with per-file atomic commit** (`.partial` → rename → Isar txn + storage counter). Crash recovery matters more than extra isolates.
6. **Versioned chunked AEAD file format** instead of raw CTR with no MAC — but **coexist with legacy blobs** until migrated.
7. **Password wrap DEK without re-encrypting the library** (rewrap envelope only on password change).
8. **Honest security-question policy.** Questions cannot unwrap a real DEK unless they protect a recovery secret. Choose: no recovery, or OS-keystore / printed recovery key.
9. **Native crypto is path-to-path + background native threads**, not a blocking MethodChannel with full file bytes.
10. **ZIP streaming + zip-slip / bomb checks.** Password-ZIP is a *source decoder* problem, not vault security.
11. **Export streams decrypt → zip entry**; never decrypt the whole vault to staging first. Mobile export **out of scope**.
12. **Measure in release mode before claiming MB/s.** Treat earlier GT Book / Z9x numbers as hypotheses.

---

## Original plan items to keep vs change

| Original suggestion | Verdict |
|---------------------|---------|
| One import pipeline + source adapters | **Keep** |
| Move PBKDF2/KDF off UI isolate | **Keep** (Flutter isolates docs) |
| Native AES later | **Keep**, after format + tests |
| Remove fake thermal/battery/isolate placeholders | **Keep** |
| Cached `totalBytesUsed` | **Keep** |
| Desktop import all media types (not images-only) | **Keep**, but **default/filter for manga images** so chapter imports stay the main path; video optional |
| Password-wrapped DEK immediately in phase 1 | **Defer to after jobs + streaming ZIP** (Copilot Phase 5). Naive wrap without migration **locks users out**. |
| Encrypt filenames immediately | **Defer.** Breaks search/sort until session index exists. Honest README first. |
| 2–4 concurrent encrypt workers on laptop | **Start at 1 (phone) / 2 (PC)**; raise only after measurement |
| Unlock ≤ 250–400 ms as hard SLA | **Soften.** OWASP: KDF should be slow (typically &lt; 1 s). Target: UI never freezes; KDF 200–800 ms in a worker. |
| Full Clean Architecture folder tree on day one | **Too heavy.** Use Flutter MVVM + repositories + a few coordinators. Copilot’s folder map is a *target*, not a first PR. |

---

## Architecture that matches Flutter *and* this app

Flutter-recommended shape, specialized for a local vault:

```
UI layer     View (thin shell) + ViewModel/controller
             DesktopShell | MobileShell | shared VaultBrowser, ImportProgress
Application  ImportCoordinator, ExportCoordinator (Windows), AuthSession, JobRunner
Data         VaultRepository, JobRepository, CredentialRepository
Services     CryptoEngine, BlobStore, ArchiveReader/Writer, Platform pickers
```

**Windows-specific:** folder picker, streaming ZIP export, Yomikiru temp decrypt of *selected folder only*.  
**Android-specific:** SAF/document tree or multi-file pick, Mihon/Tachiyomi handoff, `PowerManager` thermal listener, no export UI.

Concurrency policy (isolates + native):

- KDF and Dart CPU work: `Isolate.run` or one long-lived worker.
- File AES: native engine reads/writes **paths** (or FDs) on a background thread; Dart only gets progress events.
- Never `readAsBytes()` a ZIP or chapter folder into RAM.
- Never copy multi-MB buffers isolate-to-isolate; Isolates copy messages.

---

## Platform work policy (benchmark devices)

**iQOO Z9x (6 GB):** one active encrypt stream; ZIP entry → bounded temp or direct encrypt → delete plaintext; pause on `THERMAL_STATUS_MODERATE+`; resume same job item; image cache ~20–30 MB; lazy `ListView.builder` for chapters.

**GT Book (i5-12450H, 16 GB, AES-NI):** two file workers max until measured; AES-NI only via native backend; export streams to ZIP; GPU unused for crypto.

---

## Phased rollout (safe order)

Aligned with Copilot, trimmed for the manga product:

0. **Measure** unlock, import folder, import ZIP, Windows export on both devices (release).  
1. **Correctness / smoothness (no format change):** KDF off UI; delete fake delays; storage counter; thermal wait not skip; desktop image+optional video; disable placeholder crypto; byte progress.  
2. **One job engine + thin shells:** shared import coordinator; Windows-only export coordinator; cancel/resume; per-file commit.  
3. **Streaming ZIP** (highest OOM risk).  
4. **Versioned AEAD format** + Dart reference + then native Win/Android; mixed-version vault OK.  
5. **Password-wrapped DEK** with atomic envelope migration; document recovery policy.  
6. **Optional:** name encryption, biometrics, blob background migrate.

Each phase must still: import a nested manga folder, open pages after password, and (Windows) export that folder for phone import.

---

## Risks that would break the goal if ignored

| Risk | Mitigation |
|------|------------|
| Wrap DEK then keep “forgot password via questions” | Either questions wrap a recovery secret, or remove cryptographic recovery and warn at setup |
| Native Android AES incompatible with Windows | Same file format spec + encrypt-on-PC / decrypt-on-phone tests **before** switching default writer |
| Container/TAR “fast import” | Do not use for manga; pages must open independently |
| God-screen rewrite in one shot | Extract coordinators first; keep screens as shells until jobs work |
| Export on mobile “for completeness” | Out of scope; extra attack surface and disk use on 128 GB phones |
| Making KDF instant | Weakens password; keep calibrated slowness off the UI thread |

---

## Locked decisions

1. Flutter + Isar stay.  
2. Individual encrypted blobs stay.  
3. One import pipeline; export Windows-only.  
4. Jobs persistent, cancellable, per-file atomic.  
5. Streaming ZIP; no full-archive RAM.  
6. New crypto is versioned + authenticated; legacy readable until migrated.  
7. Password-derived KEK wraps DEK (after migration path exists).  
8. Native async file crypto is the production bulk path; Dart is tests/fallback.  
9. Metadata privacy is honest until a later phase.  
10. Claims require release-build measurement on GT Book and Z9x.

**Bottom line:** The improvement plan is **good** if implemented as Copilot’s phased, invariant-preserving design—not as a simultaneous rewrite of crypto, UI, and filenames. That path keeps the manga vault usable on both devices while making import/unlock/export actually smooth.
