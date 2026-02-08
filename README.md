# Local Vault v2.1.0 - Cross-Platform Encrypted File Storage

**Local Vault** is a production-ready encrypted file storage application built with Flutter. It provides 100% offline security with AES-256 encryption, cross-platform support (Windows + Android), and specialized manga collection management with external reader integration.

## 🚀 Key Features

### 🔒 **Security & Privacy**
- **AES-256 Encryption**: Military-grade encryption for all stored files
- **PBKDF2 Password Hashing**: 600,000 iterations for strong password protection
- **100% Offline**: No cloud dependency, all data stays on your device
- **Secure Temp Files**: Isolated temporary folders with user-controlled cleanup

### 📱 **Cross-Platform Support**
- **Windows Desktop**: Full-featured desktop application (.exe and .msix)
- **Android Mobile**: Complete mobile app with touch-optimized interface
- **Seamless Transfer**: Encrypted vault files for cross-platform collection sharing
- **Platform Detection**: Automatic UI adaptation for desktop vs mobile

### 📦 **Import/Export System**
- **ZIP Import**: Import entire folder structures with progress tracking
- **Password Options**: Export with or without password protection
- **Memory Efficient**: Streaming extraction for non-encrypted ZIPs (200MB)
- **Progress Display**: Real-time progress with debug information
- **File Order Preservation**: Natural sorting maintains correct file order (1, 2, 3... 10... 100)

### 📚 **Manga Collection Management**
- **Bulk Import**: Import entire folder structures with encryption
- **Advanced Search**: Search across file names, tags, and metadata
- **Batch Operations**: Multi-select operations for efficient management
- **External Reader Integration**: Mihon, Tachiyomi, Perfect Viewer support
- **Custom Temp Folders**: User-configurable temp folder locations for manga readers

### ⚡ **Performance Optimized**
- **Memory Efficient**: <300MB RAM usage, handles 10,000+ images smoothly
- **High Performance**: 120 FPS average, optimized for large collections
- **Progressive Loading**: Smart image caching and thumbnail generation
- **Responsive UI**: Batched operations with proper yielding prevent UI freeze

## 📥 Installation

### Windows Desktop
1. Download `local_vault.exe` or `local_vault.msix` from releases
2. Run the installer or executable
3. Create your first vault with a strong password

### Android Mobile
1. Download `local_vault_v2.1.0_android.apk` from releases
2. Enable "Install from unknown sources" in Android settings
3. Install the APK file
4. Grant storage permissions when prompted

## 🔄 Cross-Platform Workflow

### PC to Android Transfer
1. **PC**: Create and manage your manga collections in Local Vault
2. **PC**: Right-click any folder → "Export Encrypted ZIP"
   - Choose "Without Password" (recommended for Android - 200MB memory)
   - Or "With Password" (requires 1.2GB memory on Android)
3. **Transfer**: Move the ZIP file to your Android device (USB, cloud, etc.)
4. **Android**: Open Local Vault → "Import ZIP" → Select file → Enter password (if used)
5. **Android**: Watch progress with real-time debug info
6. **Android**: Browse imported folders → "Open in Manga Reader" → Choose your preferred app
7. **Android**: Use "Clean Up" to remove temp files after reading

### Supported Manga Readers
- **Mihon** (Priority detection and integration)
- **Tachiyomi** (Original and forks)
- **Perfect Viewer** (Excellent for local collections)
- **ComicScreen** (Simple and fast)
- **CDisplayEx** (Feature-rich reader)

## 🛠 Technical Specifications

### Security Implementation
- **Encryption**: AES-256-CTR with streaming for large files
- **Key Derivation**: PBKDF2 with 600,000 iterations
- **File Structure**: Encrypted blobs with plaintext metadata for performance
- **Integrity**: Built-in verification and error recovery

### Performance Achievements
- **Memory Usage**: 10.4MB idle, <300MB peak (90% improvement from original 3GB)
- **CPU Optimization**: <55% during operations (38% improvement)
- **Frame Rate**: 120 FPS average with smooth navigation
- **Large Collections**: Tested with 10,000+ images without performance degradation
- **ZIP Import**: 2900 files in 12-17 minutes with smooth progress updates

### Cross-Platform Architecture
- **Shared Business Logic**: Common services and models across platforms
- **Platform-Specific UI**: Optimized interfaces for desktop and mobile
- **Native Integration**: Platform-specific file pickers, sharing, and permissions
- **Responsive Design**: Automatic layout adaptation for different screen sizes

## 🔧 Advanced Features

### ZIP Import System (v2.1.0)
- **Progress Tracking**: Real-time file-by-file progress updates
- **Debug Display**: On-screen debug panel shows:
  - Files extracted from ZIP
  - Files encrypted successfully
  - Files saved to database
  - Recent status messages
- **Memory Management**: 
  - Non-encrypted ZIPs: 200MB constant (streaming)
  - Password-protected ZIPs: 1.2GB spike (necessary for decryption)
- **File Order**: Natural sort algorithm preserves correct order
- **UI Responsiveness**: Batched operations with yielding prevent freeze

### Android-Specific Enhancements
- **Custom Temp Folders**: Configure where manga reader temp files are created
- **Mihon Integration**: Automatic detection and priority launching
- **Storage Permissions**: Proper Android 13+ media permissions handling
- **File Provider**: Secure file sharing between apps

### Performance Optimizations
- **Main-Thread Encryption**: Batched with proper yielding for UI responsiveness
- **Progressive Image Loading**: ResizeImage with smart resolution scaling
- **Memory Management**: Strategic RepaintBoundary usage (4 widgets only)
- **Smart Caching**: 50MB image cache with LRU management

## 🚀 Version History

### v2.1.0 (Current) - ZIP Import Fix & Performance
- ✅ Fixed ZIP import (files now save correctly to database)
- ✅ Added on-screen debug display for import progress
- ✅ Implemented natural sort for correct file order
- ✅ Added export password option (with/without password)
- ✅ Memory optimization (200MB for non-encrypted, 1.2GB for encrypted)
- ✅ Smooth progress updates with batched operations

### v2.0.2 - Mobile Support Complete
- ✅ Full Android mobile app with touch-optimized UI
- ✅ Cross-platform vault import/export system
- ✅ Mihon integration with custom temp folder support
- ✅ Performance optimizations (90% memory improvement, 38% CPU improvement)
- ✅ Android 15 compatibility and file picker fixes

### v1.3 - Windows Production
- ✅ Complete Windows desktop application
- ✅ All performance optimizations implemented
- ✅ Production-ready .exe and .msix builds

## 🛡 Security & Privacy

Local Vault is designed with privacy-first principles:
- **No Telemetry**: Zero data collection or tracking
- **Offline-Only**: No internet connection required or used
- **Local Storage**: All data remains on your device
- **Open Architecture**: Transparent encryption and file handling

## 📋 System Requirements

### Windows
- Windows 10 or later
- 4GB RAM minimum (8GB recommended for large collections)
- 100MB free disk space + storage for your collections

### Android
- Android 7.0 (API level 24) or later
- 2GB RAM minimum (4GB recommended for password-protected ZIPs)
- Storage permission for file access
- 50MB free space + storage for your collections

## 📖 Usage Tips

### For Best Performance
1. **Use non-encrypted ZIPs** when possible (200MB vs 1.2GB memory)
2. **Import during charging** for large collections (2000+ files)
3. **Close other apps** during import to free memory
4. **Watch debug display** to monitor progress

### Troubleshooting
- **Import shows 0 files**: Check debug display for exact failure point
- **Out of Memory**: Use non-encrypted ZIP export option
- **Files in wrong order**: v2.1.0 fixes this with natural sort
- **Import too slow**: Normal for large collections (12-17 min for 2900 files)

## 🤝 Contributing

This is a personal project focused on secure, offline file storage with manga collection management. The codebase demonstrates modern Flutter development with cross-platform architecture, performance optimization, and security best practices.

## 📄 License

Local Vault is a personal project. All rights reserved.

---

**Latest Release**: v2.1.0 (February 8, 2026)
**Platform Support**: Windows 10+, Android 7.0+
**License**: Personal Project - All Rights Reserved
