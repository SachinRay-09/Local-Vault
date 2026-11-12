# Changelog

> This project was developed with the assistance of [Kiro](https://kiro.dev), an agentic AI IDE.

All notable changes to Local Vault are documented here.

## [3.0.0] - 2025-10-26

Major architecture redesign across six phases. First public-ready release.

### Security (Phase 5)
- DEK envelope system: vault Data Encryption Key is now wrapped by a PBKDF2-derived Key Encryption Key (200,000 iterations, HMAC-SHA256). The DEK is never stored in plaintext.
- Native AES-256-GCM replaces AES-256-CBC throughout
- Key derivation runs off the UI thread (Isolate.run) — unlock never freezes the UI
- Password change: re-wraps the DEK under a new KEK without re-encrypting vault data

### Performance (Phases 1–4)
- Native crypto backends: Windows BCrypt/CNG (AES-NI), Android javax.crypto via Conscrypt → BoringSSL → ARMv8 Crypto Extensions
- Streaming import/export pipeline: one file in RAM at a time regardless of archive size
- ZIP streaming: archive never loaded into RAM (InputFileStream / OutputFileStream)
- Android 750 MB import: ~20–30 seconds (was 8–15 minutes on old PointyCastle path, 25–50× faster)
- Windows 750 MB import: ~10–15 seconds
- Export UI jitter fixed (Phase 6): setState coalescing prevents frame drops during ZIP encoding

### UI / UX (Phase 6)
- Dark / light / system theme toggle (Settings → Appearance)
- Password change UI (Settings → Security → Change Password)
- Screenshot blocking toggle (Settings → Security → Block Screenshots)
- Crash recovery: interrupted imports resume from last committed file
- Tap / hover animations refined for Windows and Android
- Settings page redesigned: wider layout, full-page scroll
- Removed "Save to Local Gallery" feature (Android)

### Architecture (Phases 1–4)
- CryptoBridge: platform channel to native AES-256-GCM (crypto_bridge.cpp / CryptoBridge.kt)
- BlobStore: atomic partial-write commit (.partial → .bin rename)
- ExportCoordinator / ImportCoordinator: streaming pipeline with progress events
- Isar database with generated schema files
- One-file-at-a-time pipeline keeps peak RAM well under 200 MB

### Documentation
- README rewritten with accurate crypto model and AI disclosure
- GUIDE updated to current UI
- docs/PERFORMANCE.md: real hardware benchmarks with test device specs

---

## [2.5.2] - 2024-02-14

### 🎨 Added
- **Natural Sort for Folders**: Folders now sort correctly (1, 2, 10 instead of 1, 10, 2)
- **Multi-Folder Selection**: Long-press folder to enter selection mode, select multiple folders
- **Batch Move Folders**: Move multiple folders at once with circular reference validation
- **Improved Performance**: Single database transaction for batch operations (10-40x faster)

### 🔧 Improved
- **App Name**: Changed from "local_vault" to "Local Vault" on both Windows and Android
- **Memory Management**: Optimized batch operations with Set<int> for O(1) lookups
- **Error Handling**: Better validation for folder move operations
- **Documentation**: Consolidated all documentation into 5 main files

### 🐛 Fixed
- Flutter analyze issues (2 issues resolved)
- Folder hierarchy validation to prevent circular references

### 📦 Build
- Android APK: `app-release.apk` (v2.5.2+6)
- Windows Installer: `LocalVault-x86_64-2.5.2+6-Installer.exe`

### ❌ Removed
- FVP dependency temporarily removed for cross-platform compatibility
- Redundant documentation files (consolidated into main docs)

---

## [2.5.0] - 2024-02-13

### 🎨 Added
- **New App Icon**: Professional vault-themed icon for Windows and Android
- **Progress Dialogs**: Real-time progress tracking for Yomikiru/Mihon integration
  - Shows decryption progress with file counts
  - Non-dismissible during operations
  - Smooth transition to success dialog
- **Enhanced Success Dialogs**: Improved cleanup workflow
  - Clear temp folder path display
  - Copy to clipboard functionality
  - Prominent cleanup button

### 🔧 Improved
- **User Experience**: Better feedback during manga reader operations
- **Progress Tracking**: Real-time status updates during file decryption
- **Error Handling**: More informative error messages
- **Documentation**: Comprehensive README and technical documentation

### 📦 Build
- Android APK: `app-release.apk` (v2.5.0+5)
- Windows Installer: `LocalVault-x86_64-2.5.0+5-Installer.exe`

### 🐛 Fixed
- Progress dialog not showing completion state
- Success dialog appearing before progress completion
- Icon format issues for Windows build

---

## [2.2.0] - 2024-02-12

### 🎨 Added
- Progress tracking for Yomikiru (Windows) integration
- Progress tracking for Mihon (Android) integration
- Real-time file decryption progress display

### 🔧 Improved
- Temp folder creation workflow
- User feedback during operations
- Memory management during exports

---

## [2.1.0] - 2024-02-11

### ❌ Removed
- Vault file (.vault) export/import functionality
  - Feature was non-functional (0 files imported)
  - Multiple fix attempts unsuccessful
  - ZIP import/export is sufficient and reliable

### ✅ Verified
- ZIP export/import fully functional
- Password-protected ZIP support
- Cross-platform transfer via ZIP
- All existing features working correctly

### 🔧 Improved
- Cleaner UI without broken features
- Professional quality standards maintained
- ZIP import subtitle updated for clarity

### 📦 Build
- Windows: FVP re-implemented for video playback
- Android: Native video player
- Inno Setup installer with English language only

---

## [2.0.0] - 2024-02-10

### 🎉 Major Release
- Complete application rewrite
- Modern architecture with clean separation of concerns
- Cross-platform support (Windows & Android)

### 🔐 Security
- AES-256-CBC encryption
- PBKDF2 key derivation (10,000 iterations)
- Secure password storage
- Recovery key system

### 📁 File Management
- Hierarchical folder structure
- Bulk import with structure preservation
- Natural sort algorithm (1, 2, 3... 10, 11...)
- Fast search functionality
- Multi-select operations

### 📚 Manga Reading
- Yomikiru integration (Windows)
- Mihon/Tachiyomi integration (Android)
- Temp folder management
- Custom temp locations (Android)

### 🚀 Performance
- Hardware acceleration (Windows FVP)
- Memory-efficient streaming
- Progressive loading
- Batch processing
- Optimized caching

### 📱 Platform Features
- **Windows**:
  - Desktop context menus
  - File picker dialogs
  - Yomikiru integration
  - FVP video playback
  - Inno Setup installer

- **Android**:
  - Storage Access Framework (SAF)
  - Runtime permissions
  - Mihon integration
  - Custom temp folders
  - Share functionality

### 📦 Import/Export
- ZIP import (with/without password)
- ZIP export (with/without password)
- Export All functionality
- Folder structure preservation

---

## [1.0.0] - 2024-01-15

### 🎉 Initial Release
- Basic encrypted file storage
- Simple folder organization
- Windows-only support
- Manual encryption/decryption

---

## Version Numbering

Format: `MAJOR.MINOR.PATCH+BUILD`

- **MAJOR**: Breaking changes, major features
- **MINOR**: New features, non-breaking changes
- **PATCH**: Bug fixes, minor improvements
- **BUILD**: Build number (increments with each build)

## Release Types

- **Stable**: Production-ready releases (3.x.x)
- **Beta**: Testing releases (3.x.x-beta.x)
- **Alpha**: Development releases (3.x.x-alpha.x)

---

**Note**: This project follows [Semantic Versioning](https://semver.org/).
