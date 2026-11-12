# Performance Expectations — Local Vault

This document records real-world performance observations on the two devices used to build and test Local Vault. It is not a guarantee of performance on other hardware.

---

## Disclaimer

No minimum device requirements are known beyond Flutter platform minimums (Android API 26+, Windows 10+). Performance scales with hardware — specifically with AES hardware acceleration support (AES-NI on x86, ARMv8 Crypto Extensions on ARM64) and storage speed.

---

## Test Devices

### Infinix GT Book (Windows)
- **OS**: Windows 11
- **CPU**: Intel Core i5-12450H — 8 Performance cores + 8 Efficiency cores, AES-NI instruction set present
- **RAM**: 16 GB DDR4
- **Storage**: NVMe SSD (~4,500 MB/s read)

### iQOO Z9x (Android)
- **OS**: Android 14 / OriginOS 6 (API 34)
- **CPU**: Snapdragon 6 Gen 1 — Cortex-A78 + Cortex-A55 cores, ARMv8 Crypto Extensions present
- **RAM**: 6 GB LPDDR4X
- **Storage**: UFS 2.2

---

## Real-World Measurements

All measurements are from hands-on use, not automated benchmarks.

### Unlock (password entry → home screen)

| Device | Time | Notes |
|--------|------|-------|
| Infinix GT Book | ~100–200 ms | PBKDF2 runs off UI thread; spinner animates, UI never freezes |
| iQOO Z9x | ~500–600 ms | Same off-thread path; slightly slower CPU |

### Import 750 MB / 224 high-quality images (folder, Windows)

| Device | Time | Method |
|--------|------|--------|
| Infinix GT Book | ~10–15 seconds | Import Folder — AES-NI via BCrypt/CNG |

### Import 750 MB / 224 high-quality images (ZIP, Android)

| Device | Time | Method |
|--------|------|--------|
| iQOO Z9x | ~20–30 seconds | Import ZIP — ARMv8 CE via Conscrypt → BoringSSL |

### Export 750 MB / 224 images (Windows)

| Device | Time | Notes |
|--------|------|-------|
| Infinix GT Book | ~30 seconds | Export ZIP — smooth spinner, no UI jitter (after Phase 6 setState coalescing fix) |

### Image viewing

- **Both devices**: smooth scrolling and navigation through 200+ images.
- **Memory**: eviction system keeps ~5 decoded bitmaps in memory at any time regardless of folder size — no OOM at 200+ images.
- **Known behaviour**: occasional 1-frame black flash when navigating to a very large image (>4,000×6,000 px) on mobile. This is caused by GPU texture upload latency for large bitmaps on mobile hardware and is accepted behaviour. It does not affect lower-resolution images.

---

## Why It Is Fast

Local Vault uses hardware-native AES paths on both platforms:

- **Windows**: BCrypt/CNG (Windows cryptography API) uses the CPU's AES-NI instruction set directly. Throughput ~3,000 MB/s on the i5-12450H.
- **Android**: javax.crypto routed through Conscrypt → BoringSSL → ARMv8 Crypto Extensions on the Cortex-A78 cores. Each ~3 MB image encrypts in ~5 ms.

The streaming pipeline means the ZIP archive is never loaded into RAM. Only the current file being processed (~3 MB) is in memory at a time. Peak RAM during a 750 MB import stays well under 200 MB.

---

## Comparison to Previous Architecture

The previous version used PointyCastle (pure-Dart AES) with no hardware acceleration:

| Operation | Old (PointyCastle) | New (Native AES) | Speedup |
|-----------|-------------------|------------------|---------|
| Android: Import 750 MB, 224 images | 8–15 minutes | 20–30 seconds | **25–50×** |
| Windows: Unlock | ~3–5 seconds | ~100–200 ms | **~20×** |

The improvement on Android is entirely from routing through ARMv8 Crypto Extensions instead of pure-Dart computation.

---

## What We Don't Know Yet

- Performance on other Android devices (especially those without ARMv8 CE)
- Performance on lower-end Windows hardware (without AES-NI)
- Minimum viable device specs
- iOS performance (iOS is not supported)
- Behaviour with very large vaults (>10,000 files)
