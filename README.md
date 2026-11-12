# Local Vault — Encrypted Media Vault

[![Version](https://img.shields.io/badge/version-3.0.0-blue.svg)](https://github.com/SachinRay-09/Local-Vault.git)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-lightgrey.svg)](https://github.com/SachinRay-09/Local-Vault.git)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

AES-256-GCM encrypted local media vault for Windows and Android. No cloud, no tracking.

---

## What it is

Local Vault is an encrypted local media vault for Windows and Android. It stores manga, photos, and videos on your device only — no cloud sync, no account, no network traffic. Files are encrypted as opaque blobs on disk and are only accessible with the correct password.

---

## Key Features

- **AES-256-GCM encryption** for all stored files
- **PBKDF2-derived Key Encryption Key** (200,000 iterations, HMAC-SHA256) wraps the vault DEK — your password is cryptographically required to access your data
- **Native crypto backends**: Windows BCrypt/CNG (AES-NI hardware path), Android javax.crypto via Conscrypt → BoringSSL → ARMv8 Crypto Extensions
- **Streaming import/export pipeline** — only one file in RAM at a time, the full archive is never loaded into memory
- **Crash recovery** — interrupted imports resume from where they stopped
- **Dark / light / system theme**
- **Manga reader integration**: Yomikiru (Windows), Mihon/Tachiyomi (Android)
- **Folder organisation, natural sort, multi-select, batch operations**

---

## Performance Highlight

Import 750 MB / 224 images takes ~10–15 seconds on Windows (AES-NI) and ~20–30 seconds on Android (ARMv8 CE). See [docs/PERFORMANCE.md](docs/PERFORMANCE.md) for full benchmark details and test device specs.

---

## Screenshots

Screenshots coming soon.

---

## Installation

### Releases

Windows `.exe` installer and Android `.apk` are available on the [Releases page](https://github.com/SachinRay-09/Local-Vault/releases).

### Build from Source

See [DEV_SETUP.md](DEV_SETUP.md) for full build instructions.

---

## Build from Source

See [DEV_SETUP.md](DEV_SETUP.md) for prerequisites, platform setup, and build commands.

---

## Security Model

- Your password is required at every unlock. It is used to derive a Key Encryption Key (KEK) via PBKDF2, which wraps the vault's Data Encryption Key (DEK). The DEK is never stored in plaintext.
- If you forget your password, your data is permanently inaccessible — there is no backdoor by design.
- Export a recovery key before you forget your password: Settings → Security → Export Recovery Key.
- No cloud, no account, no telemetry.

---

## AI Development Disclosure

> This app was developed with the assistance of [Kiro](https://kiro.dev), an agentic AI development environment. All architecture decisions, security design, and code were reviewed and verified by the author.

---

## Documentation

- [GUIDE.md](GUIDE.md) — User guide and troubleshooting
- [DEV_SETUP.md](DEV_SETUP.md) — Quick setup checklist for new developers
- [DEVELOPMENT.md](DEVELOPMENT.md) — Full development guide, architecture, and project structure
- [CHANGELOG.md](CHANGELOG.md) — Version history
- [docs/PERFORMANCE.md](docs/PERFORMANCE.md) — Real-world benchmark data with device specs

---

## Known Limitations

- Image viewing may show a 1-frame black flash on very large images (>4000×6000 px) on mobile, caused by GPU texture upload latency. This is accepted behaviour and does not affect lower-resolution images.
- Temp files from manga reader sessions are unencrypted and must be cleaned up manually after each reading session (use the in-app cleanup dialog).

---

## License

Copyright © 2024–2025 Local Vault. All rights reserved. Proprietary.

---

## Support

- **GitHub Issues**: [github.com/SachinRay-09/Local-Vault/issues](https://github.com/SachinRay-09/Local-Vault/issues)
