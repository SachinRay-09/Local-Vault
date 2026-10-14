# Local Vault - Secure Encrypted Media Storage

[![Version](https://img.shields.io/badge/version-2.5.2-blue.svg)](https://github.com/yourusername/local_vault)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Android-lightgrey.svg)](https://github.com/yourusername/local_vault)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

**Your Private Media Sanctuary with Strong AES-256 Encryption**

---

## 🔐 What is Local Vault?

Local Vault is a cross-platform encrypted storage application designed for **complete privacy**. Store your sensitive media (manga, photos, videos, documents) with AES-256 encryption that keeps everything local on your device - no cloud, no tracking, no data collection.

### Why Local Vault?

- 🔒 **True Privacy**: Everything stays on YOUR device with AES-256 encryption
- 📱 **Manga Reader Integration**: Direct export to Tachiyomi/Mihon (Android) and Yomikiru (Windows)
- ⚡ **Bulk Operations**: Import entire folders or ZIP archives in seconds
- 🚫 **Zero Cloud**: No servers, no uploads, works 100% offline
- 💰 **One-Time Purchase**: No subscriptions, no ads, lifetime access

---

## ✨ Key Features

### Security & Privacy
- **AES-256 Encryption** - Industry-standard AES-256 for all stored files
- **Secure Key Storage** - Keys stored in OS-level secure storage. Your password unlocks the app; the vault encryption key is stored separately in the OS keystore (Windows Credential Manager / Android Keystore).
- **Password Protection** - Master password guards your vault
- **No Cloud Sync** - Everything stays local, no internet required

### File Management
- **Folder Organization** - Create nested folders like a file manager
- **Natural Sort** - Folders sort correctly (1, 2, 10 not 1, 10, 2)
- **Multi-Select** - Select and move multiple folders/files at once
- **Batch Move** - Move multiple folders in one operation with validation
- **Advanced Search** - Find files instantly by name or tag
- **Batch Import** - Import entire folders or ZIPs with progress tracking

### Manga Reading
- **Yomikiru Integration** (Windows) - One-click export to manga reader
- **Mihon/Tachiyomi Integration** (Android) - Direct export support
- **Progress Tracking** - Real-time decryption progress
- **Cleanup Tools** - Easy temp folder cleanup after reading

### Performance
- **Optimized Memory** - ~300MB peak usage
- **Fast Import** - 50-100 files per second
- **Hardware Acceleration** - GPU-accelerated video on Windows
- **60 FPS UI** - Smooth performance on mid-range devices

---

## 📋 System Requirements

### Windows
- **OS**: Windows 10/11 (64-bit)
- **CPU**: Intel Core i3 (4th gen) / AMD Ryzen 3 or equivalent
- **RAM**: 4GB minimum (8GB recommended)
- **Storage**: 500MB + space for your content

### Android
- **OS**: Android 8.0+ (API 26+)
- **CPU**: ARM64 processor (Snapdragon 450 / Helio P22+)
- **RAM**: 2GB minimum (4GB recommended)
- **Storage**: 200MB + space for your content

---

## 🚀 Quick Start

### Installation

**Windows:**
```bash
# Download LocalVault-x86_64-2.5.2+6-Installer.exe
# Run installer and follow wizard
```

**Android:**
```bash
# Download app-release.apk
# Enable "Install from Unknown Sources"
# Install APK and grant storage permissions
```

### First Use

1. **Create Master Password** - Choose a strong password (REMEMBER IT!)
2. **Import Files** - Menu → Import Folder or Import ZIP
3. **Organize** - Create folders, add tags, search
4. **Access Anytime** - Enter password to unlock vault

---

## 📖 Documentation

- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Setup development environment
- **[GUIDE.md](GUIDE.md)** - Complete user guide and troubleshooting
- **[SELLING_STRATEGY.md](SELLING_STRATEGY.md)** - Product description and features
- **[CHANGELOG.md](CHANGELOG.md)** - Version history and updates

---

## ⏱️ Performance Note

**About Processing Time:**  
Encryption is CPU-intensive. Large files (1GB+) may take 5-10 minutes to import depending on your device's CPU. This isn't a bug - it's your content being secured with AES-256 encryption. Once encrypted, access is instant. The wait is only during initial import.

---

## 🔒 Security & Privacy

### What We Do
✅ AES-256 encryption for all files  
✅ Secure key storage in OS keychain  
✅ 100% local storage, no cloud  
✅ No data collection or tracking  
✅ Works completely offline  

### What We DON'T Do
❌ No cloud backup (by design)  
❌ No account creation  
❌ No analytics or tracking  
❌ No vault key recovery — security questions reset only the app unlock password, not the vault encryption key; if the key is lost, data is permanently inaccessible
❌ No internet connection required  

---

## 🛠️ Development

Want to contribute or build from source? See [DEVELOPMENT.md](DEVELOPMENT.md) for:
- Prerequisites and setup
- Building for Windows and Android
- Project structure
- Contributing guidelines

---

## 📊 Version History

**v2.5.2** (Current)
- ✅ Natural sort for folders
- ✅ Multi-folder selection and batch move
- ✅ App name changed to "Local Vault"
- ✅ Performance optimizations

See [CHANGELOG.md](CHANGELOG.md) for complete history.

---

## 🐛 Known Issues & Limitations

- **FVP Video**: Windows-only hardware acceleration (Android uses native player)
- **ZIP Compatibility**: Streaming extraction may fail with manually modified ZIPs
  - Solution: Extract ZIP in File Explorer first, then use "Import Folder"
- **Memory Usage**: Password-protected ZIP imports use 1.2GB+ RAM temporarily
  - Solution: Use no-password ZIP (200MB RAM) or Import Folder on Windows
- **Temp Folder Cleanup**: Manual cleanup required after manga reading (by design to prevent data loss)
- **Android 15+**: Requires Storage Access Framework permissions

---

## 📄 License

Copyright © 2024 Local Vault. All rights reserved.

This software is proprietary. Unauthorized copying, distribution, or modification is prohibited.

---

## 🤝 Support

- **Email**: shadow99810@gmail.com
- **Issues**: [GitHub Issues](https://github.com/yourusername/local_vault/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/local_vault/discussions)

---

## 🙏 Acknowledgments

Built with:
- [Flutter](https://flutter.dev) - Cross-platform framework
- [Isar](https://isar.dev) - High-performance database
- [Yomikiru](https://github.com/mienaiyami/yomikiru) - Windows manga reader
- [Mihon](https://mihon.app) - Android manga reader

---

**Built with ❤️ for privacy-conscious users**
