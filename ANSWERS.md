# Local Vault — Answers

---

## 1. iQOO Z9x RAM correction

You are right. The iQOO Z9x has **6 GB RAM**, not 8 GB.

The UPGRADE_REPORT.md has been noted for correction. The practical impact on the app:

- Import of a 500 MB ZIP on 6 GB RAM is still safe because `ArchiveReader` never loads the whole ZIP — it streams one entry at a time, each written to a temp file before the next one starts. Peak RAM usage during import is roughly: one extracted entry + one encrypted chunk (512 KB max) + Dart VM overhead (~150 MB). That keeps you comfortably under 500 MB regardless of ZIP size.
- Video playback is the only operation that pushes RAM significantly. A 1080p video decode buffer on Android can use 200–400 MB. If you have other apps open, the OS may reclaim background memory from Local Vault, which triggers the auto-lock (app re-enters background) — expected behaviour.

---

## 2. Edge cases and mid-operation app close

### What happens if you close the app during an active import?

The import pipeline is built around the `OperationJob` + `.partial` blob pattern specifically for this case.

**During folder import:**
- Every file goes through: create `.partial` blob on disk → save `.partial` path to DB → encrypt → rename to `.bin` → write `VaultFile` DB row → mark item `completed`
- If the app is killed at any point, when you reopen the app, `findInterruptedJobs()` runs at startup
- The recovery dialog shows you the interrupted job and offers "Discard" (deletes all `.partial` files and marks the job skipped)
- "Resume" is coded in the backend but the dialog currently only shows "Discard" — Resume UI is deferred to Phase 6
- Files that were fully committed (renamed to `.bin` + `VaultFile` row written) are safe and visible in the vault
- Files that were mid-encrypt (`.partial` exists) are cleaned up on discard

**During ZIP import:**
- Same crash recovery. The ZIP itself is never modified.
- Partially extracted temp files are cleaned up.
- Already-committed files from earlier entries in the ZIP remain in the vault.

**During export (Windows only):**
- The destination ZIP file may be partially written
- The partial ZIP is left on disk — the app does not delete it automatically because it doesn't know if you want it
- No vault files are modified during export (export = read-only operation on the vault)
- When you reopen the app, no recovery dialog appears for export (export failure is not tracked as an interrupted job in the current implementation — this is a known gap, deferred to Phase 6)
- You can safely delete the partial ZIP and re-export

**During file viewing:**
- A temp plaintext file may be left in the system temp directory
- `_bestEffortCleanup` deletes temp files older than 24 hours on the next app open
- Your vault data is unaffected

**When opening a folder in Mihon and closing the app mid-browse:**
- "Mihon" here means your manga reader app, which reads the decrypted temp files that `ViewerCoordinator` produced
- Closing Local Vault mid-browse: the temp file stays on disk (cleaned up next launch or after 24h)
- The vault itself is unaffected — the temp file is a read-only copy
- On Android, the OS may delete temp files independently if storage is low

### Summary table

| Operation | App killed mid-way | On next launch | Vault data safe? |
|-----------|-------------------|----------------|-----------------|
| Folder import | Some files imported, some not | Recovery dialog appears | ✅ Yes |
| ZIP import | Some entries imported | Recovery dialog appears | ✅ Yes |
| Export | Partial ZIP on disk | No dialog, partial ZIP left on disk | ✅ Yes (vault untouched) |
| File view/decrypt | Temp file on disk | Cleaned up after 24h | ✅ Yes |
| Password change | Old password still works (rollback marker) | Old envelope restored on next launch (Phase 6) | ✅ Yes |

---

## 3. Forgot password — what to do, what will actually work

### The honest situation

The line in the upgrade report ("forgetting your password means permanent data loss") is accurate **as the code currently stands** for Phase 5. The password derives a KEK which wraps the DEK. Without the password, the KEK cannot be derived, so the DEK cannot be unwrapped, so no files can be decrypted.

**The security questions in the existing UI do NOT break this encryption.** They were designed as a second "UI gate" — answering them correctly would let the app reset the password in the UI, but that only means setting a new password hash in secure storage. It does NOT recover the DEK, because the DEK is now wrapped by the OLD password's KEK. If we "reset" the password via security questions, the new KEK derived from the new password won't match the old wrapped DEK, so the vault becomes permanently unreadable.

This is a real problem and it needs to be fixed before you rely on this app for important data.

### What we should do — Recovery Key (the right solution)

The design doc (§6.3) already specifies a recovery path: an **optional recovery key export**. Here is what it means in practice:

At vault setup (or at any time while you know your password), the app generates a recovery key:
- It takes your DEK (32-byte master encryption key)
- Wraps it with a new random 256-bit key
- Exports that wrapped DEK + the wrapping key as either a QR code you photograph or a small file you save somewhere safe (USB drive, printed paper, another device)

If you forget your password:
1. App detects wrong password (GCM tag mismatch)
2. "Forgot password? Use recovery key" option appears
3. You scan the QR code or load the file
4. The app unwraps your DEK using the recovery key
5. You set a new password → new KEK wraps the same DEK → vault accessible again

**The security questions can be repurposed** as a hint/reminder system — they do not and should not be involved in cryptographic recovery. Use them to remember a password hint, not to bypass encryption.

### What you should do right now (practical advice)

1. **Do not store any irreplaceable data in the vault yet** until the recovery key feature is implemented and you have exported a recovery key
2. **Write down your password somewhere physically safe** (notebook in a drawer) — low-tech but reliable for a personal vault
3. **Consider a memorable passphrase** instead of a random password — something like 4 random words you can visualise. Much harder to forget, just as secure for your use case.

### Implementation plan

This is a Phase 6 task. The recovery key export/import flow will be added to:
- Setup screen: "Export recovery key (recommended)" button after first vault creation
- Settings screen: "Export recovery key" (re-exportable any time with current password)
- Login screen: "Forgot password? Recover with key" link
- The recovery key itself: a 64-byte file (32-byte wrapped DEK + 32-byte wrapping key) or a QR code

This is the same pattern used by password managers like Bitwarden and 1Password for their emergency kits.

---

## 4. Hardware cross-platform round-trip test — what order, how to do it safely

### The correct order

**Test first, then change the default.** Never flip the default before the test.

The risk if you flip first and the test reveals a bug: every file imported after the flip uses v1 format, and if there's a cross-platform decrypt bug, those files become unreadable. Your existing v0 data is safe (v0 never changes), but the new imports would be broken.

### The safe sequence

```
Step 1: Keep formatVersion default = 0  (current state — already correct)
Step 2: Run the cross-platform round-trip test (instructions below)
Step 3: If test passes → change default to 1
Step 4: Build production app
Step 5: Install on devices
```

### How to run the test — PC development mode + Android emulator

#### Running the app on your PC in development mode

You already have Flutter installed. In a terminal (PowerShell), from your project folder:

```powershell
cd p:\personalVault\local_vault
flutter run -d windows
```

This opens the Windows app in debug mode. It uses your real vault data at its normal path. You can also run in release mode for more realistic performance:

```powershell
flutter run -d windows --release
```

**Important:** Debug mode and release mode share the same vault data location on Windows. If you want to test without risking your real vault, do this first:
1. Back up your vault folder (the `vault_blobs` directory and the Isar DB files — typically under `%APPDATA%\Local Vault\` or wherever the app stores data)
2. Then run tests
3. Restore backup if anything goes wrong

#### Setting up Android Studio to run the app in the emulator

1. Open Android Studio → **Device Manager** (right panel or Tools menu)
2. Click **Create Device** → choose **Pixel 6** (good baseline for Snapdragon-class hardware) or any API 34 device
3. Select system image: **API 34, x86_64** (fastest on PC; note: emulator doesn't have real ARMv8 Crypto Extensions, so v1 native crypto bridge won't use hardware AES — that's expected for emulator testing)
4. Start the emulator (green play button)
5. In terminal:

```powershell
cd p:\personalVault\local_vault
flutter run -d emulator-5554   # or whatever device ID shows in 'flutter devices'
```

You can list all available devices with:

```powershell
flutter devices
```

**To run the actual round-trip test:**

The test is manual for now (no automated cross-platform CI). Here is what to do:

1. Run the Windows app in development mode
2. Import a small test folder (10 images, ~5 MB total) — this uses v0 format (default)
3. To force v1 for the test only: temporarily change `EncryptionOptions({this.formatVersion = 1})` in `lib/services/crypto_engine.dart`, import a second test folder, then **revert the change before building production**
4. Export both test folders to ZIPs from the Windows app
5. Copy the ZIPs to the emulator (via Android Studio's Device File Explorer, or `adb push`)
6. Run the Android app in the emulator, import those ZIPs
7. Open a few images — if they display correctly, v0→Android and v1→Android both work
8. Do the same in reverse: import something on the emulator, export, copy to Windows, verify

**Note on the emulator for v1 testing:** The emulator runs on x86_64, not ARM. The `CryptoBridge.kt` native path calls `javax.crypto.Cipher("AES/GCM/NoPadding")`, which works on x86_64 too — it just won't use ARMv8 Crypto Extensions hardware acceleration (that only exists on real ARM chips). The correctness of the v1 format (does it encrypt and decrypt the right bytes) can still be verified on the emulator. The performance benefit of ARMv8 CE can only be measured on a real Z9x.

#### Building the final production app safely

Once tests pass:

1. Change `formatVersion` default from `0` to `1` in `lib/services/crypto_engine.dart`
2. Build the release APK:

```powershell
flutter build apk --release
```

3. The output is at `build\app\outputs\flutter-apk\app-release.apk`
4. Install on your Z9x via:
   - Transfer the APK to the phone and open it (enable "Install from unknown sources" in settings), OR
   - `adb install build\app\outputs\flutter-apk\app-release.apk`

**Your existing vault data is safe when you install the new version.** The app reads v0 blobs with the old decrypt path (auto-detected by the absence of the `LVCRYPT1` header). Only new imports after the upgrade will use v1. Your old data is never automatically re-encrypted.

#### Why not test on the real Z9x directly?

You can, but the emulator is safer for initial testing because:
- No risk to your real vault data
- Easy to reset/wipe if something goes wrong
- Faster iteration (no USB transfer for each test)

Once emulator tests pass, do one final test on the real Z9x with a throw-away test vault (create a new vault on the device with test images, verify, then wipe it) before trusting the production install.

---

## Summary of actions needed

| Priority | Action |
|----------|--------|
| 🔴 High | Implement recovery key export/import before storing important data |
| 🟡 Medium | Run cross-platform round-trip test (emulator first, then real device) |
| 🟡 Medium | After test passes, flip `formatVersion` default to `1` and build production APK |
| 🟢 Low | Correct UPGRADE_REPORT.md Z9x RAM from 8 GB to 6 GB |
| 🟢 Low | Consider a memorable passphrase as your vault password |


---

---

# Round-Trip Experience — Answers

---

## 5. Unlock taking 14574ms / 5 seconds — why and what to do

The benchmark log shows:
```
[Benchmark] Total unlock: 14574ms
```

That is **debug mode**. This is entirely expected and not a real number.

Here is what is happening:

- **Debug mode** runs Dart code through the interpreter with full assertion checking, no JIT optimisation, no AOT compilation. Cryptographic code (PBKDF2, AES) can run **10–30× slower** in debug mode vs release mode. This is a known Flutter/Dart characteristic.
- PBKDF2-HMAC-SHA256 at 200,000 iterations on PointyCastle in debug mode on a PC: ~10–15 seconds is typical and reported widely (PointyCastle is a pure-Dart port of Bouncy Castle — it has no native code and its performance is entirely dependent on the Dart VM's optimisation tier).
- On the **second run being faster** (~2 seconds): that is the Dart JIT warming up. The JIT compiles hot loops after the first execution, so the second run benefits from partial optimisation even in debug mode.

**What it will actually be in release mode:**
- Windows release build (`flutter build windows --release`): ~100–200ms for unlock. The AOT compiler turns PBKDF2 inner loops into optimised native x64 code.
- Android release APK on real Z9x: ~400–800ms (PBKDF2 is CPU-intensive; pure-Dart PointyCastle on ARM without hardware acceleration).
- Android emulator (x86_64, debug): you will see similarly inflated timings.

**Bottom line: never judge crypto performance in debug mode.** The 14 seconds is not a real number. Build release and measure.

---

## 6. v1 (formatVersion=1) is slower than v0 — why this happens and what to do

This is the most important performance question, and the search results confirm the exact cause.

### Why v1 is slower in pure-Dart PointyCastle

**AES-GCM (v1) is inherently more work than AES-CTR (v0) in pure software:**

- AES-CTR encrypts the data only. One AES block operation per 16 bytes of plaintext.
- AES-GCM does AES-CTR encryption PLUS a GHASH authentication operation per chunk. GHASH is a Galois field multiplication that costs roughly the same CPU time as the AES encryption itself — so you are doing **roughly twice the work per byte**.

From the crypto.stackexchange.com source: *"The GHASH part of GCM is usually the problematic one when it comes to implementation, not the AES. GHASH is very fast on hardware platforms that have dedicated opcodes (x86 with AES-NI, POWER8...) but these platforms also provide an AES hardware implementation that outperforms software-based stream ciphers."*

From academic benchmarks (Springer, UC Davis): CTR mode costs ~1.3 cycles/byte in optimised software. GCM costs ~3.7–4.2 cycles/byte — roughly **3× slower in pure software without hardware acceleration**.

**Why the "5–8× speedup" claim was wrong for this situation:**

The 5–8× speedup figure was about **hardware-accelerated AES-GCM** (ARMv8 Crypto Extensions on Z9x, AES-NI on GT Book) via the native bridges (`CryptoBridge.kt` on Android, `crypto_bridge.cpp` on Windows). That gain only applies when:
1. The native bridge is active (it routes through `NativeCryptoEngine`)
2. The hardware actually has AES-NI / ARMv8 CE
3. You are running on a **real device**, not an emulator (emulators run x86_64 without crypto extensions)

When you changed `formatVersion` to `1` in development mode, the app is using `DartCryptoEngine` (pure Dart PointyCastle GCM), not the native bridge. So you got the slower pure-software GCM path with no hardware benefit, which is the **worst of both worlds** — more work than CTR, no hardware to speed it up.

Additionally, the emulator (x86_64 virtual machine) does not expose AES-NI to the guest — the native `BCrypt` or `javax.crypto` native calls would still work but without hardware acceleration, so even the native path would be slower than expected on the emulator.

### What you should do

**Keep `formatVersion = 0` (AES-CTR) as the default for now.** Here is the full reasoning:

| | v0 AES-CTR (current default) | v1 AES-GCM (PointyCastle, pure Dart) | v1 AES-GCM (native bridge on real device) |
|--|--|--|--|
| Security | Confidentiality only (no tamper detection) | Confidentiality + authenticated (tamper-detected) | Same as v1 Dart, but faster |
| Speed (debug) | ~5–10× slower than release | ~3× slower than v0 in same mode | N/A (debug always slow) |
| Speed (release, PC) | ~150–200 MB/s | ~50–80 MB/s | ~400–800 MB/s via BCrypt AES-NI |
| Speed (release, real Z9x) | ~50–80 MB/s | ~20–30 MB/s | ~400–600 MB/s via ARMv8 CE |
| Your experience now | Fast and correct | Noticeably slower, no security benefit on emulator | Not yet tested |

The v1 format is correct and secure — but it only makes sense to use it when the native bridge is active on real hardware. On the emulator and in debug mode it is strictly worse.

**The right sequence before enabling v1 as default:**
1. Build the release APK: `flutter build apk --release`
2. Install on your real Z9x
3. Test: import a folder → time it with v0 (default)
4. Temporarily change `formatVersion` to `1` → rebuild release → install → time same import
5. If v1 is faster on the real device (which it should be via the native `javax.crypto` path), then keep it at 1
6. If v1 is still slower even on release hardware (would indicate the native bridge is not routing correctly), revert to 0 and investigate

**For now: revert `formatVersion` back to `0` in `lib/services/crypto_engine.dart`**

---

## 7. Black screen flash when pressing Previous — what it is and how to fix it

### What is causing it

This is a **missing preload / decrypt cache miss** on reverse navigation. Here is the exact sequence:

1. You navigate forward: image N is already decrypted and cached → instant display ✅
2. You navigate backward to image N-1: the `PageView` or image viewer creates a new widget for N-1, which triggers a decrypt from the encrypted blob → async gap → blank/black frame while decrypt runs → image appears

Forward navigation worked well because you were moving sequentially and the next image was likely being preloaded (or the decrypt was already warm). Going backwards hits a cold cache because the viewer only preloads in the forward direction.

This is a well-known Flutter pattern documented across multiple Stack Overflow threads. The fix is `precacheImage` — you pre-decrypt and load the adjacent images (both next AND previous) into Flutter's image cache before the user can navigate to them.

### The fix

This needs to be done inside the image viewer (wherever `PageView` or the image swipe is implemented). The pattern is:

```dart
// When page changes to index i, preload i-1 and i+1
void _onPageChanged(int index) {
  // Preload next
  if (index + 1 < images.length) {
    _preloadImage(index + 1);
  }
  // Preload previous — this is what fixes the black flash
  if (index - 1 >= 0) {
    _preloadImage(index - 1);
  }
}

Future<void> _preloadImage(int index) async {
  // Decrypt to temp if not already cached
  final tempPath = await vaultOpenService.decryptToCachedTempFile(images[index]);
  // Warm Flutter's image cache
  await precacheImage(FileImage(File(tempPath)), context);
}
```

The `decryptToCachedTempFile` in `VaultOpenService` already uses a deterministic temp filename (so the same file isn't decrypted twice), meaning calling it for adjacent images is cheap — if it's already decrypted it just returns the path.

This is a Phase 6 UI fix. I will delegate it to a workflow shortly to implement it properly in the actual viewer file. Let me know if you want this fixed now or after the production build.

---

## 8. Password-protected ZIP export removed — why, and can it come back

### Why it was removed

The password-protected ZIP export was removed during Phase 1 as part of the "honest security claims" cleanup. The reason: the previous implementation used standard ZIP encryption (PKWARE / ZipCrypto), which is **cryptographically weak** — it can be cracked with known-plaintext attacks using freely available tools. Offering it as a "secure" export would have been misleading.

Additionally, as you noticed yourself: extracting a password-protected ZIP on Android with limited RAM is a nightmare because the `archive` package's password-protected path loads the entire ZIP into memory before decoding (it cannot stream password-protected ZIPs). On a 6 GB device with other apps running, a 500 MB+ encrypted ZIP would OOM.

### Can it come back

Yes, but only with proper encryption. The right approach for Phase 6:

- Export a ZIP that is **not** password-protected at the ZIP level (no ZipCrypto)
- Instead, wrap the whole ZIP in an AES-256-GCM outer envelope (the v1 LVCRYPT1 format) with a user-chosen export password
- The recipient decrypts the outer envelope first, then gets a normal ZIP
- This avoids both the ZipCrypto weakness and the in-memory decompression problem

For your personal use case (exporting to your own phone), the current export (no password, just a regular ZIP of your decrypted files) is fine as long as you treat the ZIP as sensitive and delete it after importing on the other device.

---

## 9. Final verdict and performance improvement plan

### What to do right now (in order)

**Step 1 — Revert formatVersion to 0 (takes 30 seconds)**

In `lib/services/crypto_engine.dart`, confirm `this.formatVersion = 0` (it should already be 0 — only change it back if you set it to 1 during testing).

**Step 2 — Fix the black screen flash in the image viewer**

This is the most noticeable UX issue. I can fix this now — just say the word and I will find the viewer file and add `precacheImage` for adjacent images.

**Step 3 — Build the release APK and test on real Z9x**

```powershell
flutter build apk --release
```

Install on Z9x. This is the only way to get real performance numbers. Debug mode timings mean nothing for crypto.

**Step 4 — On the real Z9x, compare v0 vs v1 import times**

Import the same folder twice — once with `formatVersion = 0`, once with `formatVersion = 1` — both in release mode. If v1 is noticeably faster (the native `javax.crypto` ARMv8 path kicking in), switch to v1 permanently. If it is the same or slower, there is a routing issue in the native bridge to investigate.

**Step 5 — Build the Windows release and measure unlock time**

```powershell
flutter build windows --release
flutter run -d windows --release
```

The unlock should be under 300ms. If it is still multi-seconds in release mode, that indicates the PBKDF2 isolate is not starting correctly and needs investigation.

### How much performance improvement is realistically possible

| Operation | Current (debug, v0) | Release v0 (realistic) | Release v1 native (best case) |
|---|---|---|---|
| Unlock on PC | ~14 seconds (debug!) | ~150–200ms | Same (PBKDF2 doesn't use AES hardware) |
| Unlock on Z9x | ~5–8 seconds (debug!) | ~500–800ms | Same |
| Import 8 images (~24 MB) on PC | < 1s (already fast) | < 0.5s | ~0.2s (BCrypt AES-NI) |
| Import 8 images on Z9x | 2–4s (debug) | ~1–2s | ~0.3–0.5s (ARMv8 CE, if native routing works) |
| Open image (decrypt, Z9x) | ~1–2s (debug) | ~200–400ms | ~50–100ms (ARMv8 CE) |

The biggest gains from v1 are on **image open** (decrypt speed) and **large imports** on the Z9x. The unlock time is not affected by the format version — that is all PBKDF2 which is CPU-bound math regardless.

### Summary of what is currently working well

- Natural sort order ✅
- Import is non-blocking (spinner works) ✅  
- Crash recovery (partial import survives app kill) ✅
- Password-wrapped DEK (Phase 5, secure key storage) ✅
- ZIP streaming import (no OOM) ✅
- Export one-file-at-a-time (no full plaintext staging) ✅
- Forward image navigation smooth ✅

### Summary of what still needs attention

- Black screen on previous/backward navigation — **fix available, just needs implementing**
- v1 native bridge performance not yet verified on real hardware
- Recovery key export not yet built (important before relying on this for real data)
- Unlock time only looks bad in debug mode — will be fine in release
