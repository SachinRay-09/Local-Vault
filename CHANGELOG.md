# Changelog

All notable changes to Local Vault will be documented in this file.

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
- Save to Local Gallery
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

- **Stable**: Production-ready releases (2.x.x)
- **Beta**: Testing releases (2.x.x-beta.x)
- **Alpha**: Development releases (2.x.x-alpha.x)

## Support

- **Current Version**: 2.5.0 (Full support)
- **Previous Version**: 2.2.0 (Security updates only)
- **Legacy Versions**: No longer supported

---

**Note**: This project follows [Semantic Versioning](https://semver.org/).
