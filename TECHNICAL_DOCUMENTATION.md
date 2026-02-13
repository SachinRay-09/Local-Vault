# Local Vault - Technical Documentation

**Version 2.5.0** | Complete Technical Reference

## 📐 Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    User Interface Layer                  │
│  ┌──────────────────┐         ┌──────────────────┐     │
│  │  Windows (Desktop)│         │  Android (Mobile)│     │
│  │  - Home Screen    │         │  - Mobile Home   │     │
│  │  - Settings       │         │  - Permissions   │     │
│  │  - Yomikiru Int.  │         │  - Mihon Int.    │     │
│  └──────────────────┘         └──────────────────┘     │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│                   Business Logic Layer                   │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Services                                         │  │
│  │  - VaultRepository    - ImportExportService      │  │
│  │  - FileCryptoService  - YomikiruIntegration      │  │
│  │  - AuthService        - AndroidMangaService      │  │
│  │  - SettingsService    - BulkImportService        │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          │
┌─────────────────────────────────────────────────────────┐
│                    Data Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Isar Database│  │ Encrypted    │  │ Secure       │ │
│  │ - Metadata   │  │ File Storage │  │ Storage      │ │
│  │ - Folders    │  │ - Blobs      │  │ - Passwords  │ │
│  │ - Files      │  │ - Temp Files │  │ - Keys       │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## 🗄️ Database Schema

### Isar Collections

#### VaultFolder
```dart
class VaultFolder {
  Id id;                    // Auto-increment primary key
  String name;              // Folder name
  int? parentId;            // Parent folder ID (null = root)
  DateTime createdAt;       // Creation timestamp
  DateTime updatedAt;       // Last update timestamp
}
```

#### VaultFile
```dart
class VaultFile {
  Id id;                    // Auto-increment primary key
  String originalName;      // Original filename
  String storedBlobName;    // Encrypted blob filename
  int? parentFolderId;      // Parent folder ID (null = root)
  int byteSize;             // Original file size
  String ivBase64;          // Initialization vector (Base64)
  DateTime createdAt;       // Creation timestamp
  int sortOrder;            // File order (preserves import order)
}
```

#### AppSettings
```dart
class AppSettings {
  Id id = 1;                // Singleton (always ID 1)
  String? customTempFolderPath;  // Android temp folder location
  bool? hardwareAcceleration;    // Enable GPU acceleration
  int? maxCacheSize;             // Cache size limit
}
```

### Indexes
- `VaultFolder.parentId` - Fast folder hierarchy queries
- `VaultFile.parentFolderId` - Fast file listing
- `VaultFile.sortOrder` - Maintains file order
- `VaultFile.originalName` - Fast search

## 🔐 Encryption Implementation

### Encryption Flow

```
Original File → Read Bytes → Encrypt → Store Blob → Save Metadata
                                ↓
                         AES-256-CBC
                         Random IV
                         PBKDF2 Key
```

### Key Derivation
```dart
// PBKDF2 with SHA-256
iterations: 10,000
keyLength: 32 bytes (256 bits)
salt: Random per vault
```

### File Encryption
```dart
Algorithm: AES-256-CBC
IV: Random 16 bytes per file
Padding: PKCS7
Output: Encrypted bytes + IV (stored separately)
```

### Storage Structure
```
vault_data/
├── blobs/
│   ├── {timestamp}_{uuid}_blob.enc    # Encrypted file data
│   ├── {timestamp}_{uuid}_blob.enc
│   └── ...
└── temp/
    └── {temp files for decryption}
```

## 📦 Import/Export System

### ZIP Import Flow

```
ZIP File → Extract → Detect Password → Decrypt (if needed) → Encrypt → Store
                          ↓
                    Password Dialog
                    (if encrypted)
                          ↓
                    Stream Processing
                    (memory efficient)
```

### ZIP Export Flow

```
Vault Files → Decrypt → Create ZIP → Encrypt (optional) → Save
                 ↓
           Batch Processing
           Progress Tracking
                 ↓
           Password Dialog
           (if requested)
```

### Natural Sort Algorithm

```dart
// Ensures proper file ordering: 1, 2, 3... 10, 11... 100
// Not: 1, 10, 100, 2, 20, 200...

compareNatural(String a, String b) {
  // Extract numbers and compare numerically
  // Compare non-numeric parts alphabetically
  // Handles: 0.1, 0.2... 1, 2, 3...
}
```

## 🎨 UI Components

### Progress Dialogs

#### Yomikiru Progress Dialog (Windows)
```dart
_YomikiruProgressDialog
├── Shows real-time status
├── Tracks file decryption progress
├── Non-dismissible during operation
├── 500ms completion display
└── Transitions to success dialog
```

#### Mihon Progress Dialog (Android)
```dart
_MihonProgressDialog
├── Shows real-time status
├── Tracks file decryption progress
├── Non-dismissible during operation
├── 500ms completion display
└── Transitions to success dialog
```

### Success Dialogs

#### Features
- Temp folder path display
- Copy path to clipboard
- Cleanup button
- Mihon/Yomikiru detection status
- Usage instructions

## 🔄 Service Architecture

### VaultRepository
**Purpose**: Core database operations

**Key Methods**:
- `createFolder(name, parentId)` - Create folder
- `addMedia(name, parentId, bytes)` - Add encrypted file
- `listFiles(parentId)` - List files in folder
- `listFolders(parentId)` - List subfolders
- `deleteFolder(folderId)` - Delete folder recursively
- `searchFiles(query)` - Search files by name

### FileCryptoService
**Purpose**: File encryption/decryption

**Key Methods**:
- `encryptFile(sourcePath, destPath, password)` - Encrypt file
- `decryptFile(sourcePath, destPath, password, iv)` - Decrypt file
- `generateIV()` - Generate random IV
- `deriveKey(password, salt)` - Derive encryption key

### ImportExportService
**Purpose**: ZIP import/export operations

**Key Methods**:
- `importZip(zipPath, password)` - Import ZIP file
- `exportAllToZip(outputPath, usePassword)` - Export entire vault
- `exportFolderToZip(folderId, outputPath, usePassword)` - Export folder
- `detectZipPassword(zipPath)` - Detect if ZIP is encrypted

### YomikiruIntegrationService (Windows)
**Purpose**: Yomikiru manga reader integration

**Key Methods**:
- `openFolderInYomikiru(folder, onProgress)` - Export and launch
- `cleanupTempFolder(path)` - Remove temp files
- `getCurrentTempFolders()` - List active temp folders

**Flow**:
1. Create temp directory
2. Get all files in folder (recursive)
3. Decrypt files with progress tracking
4. Launch Yomikiru with folder path
5. Return temp path for cleanup

### AndroidMangaService (Android)
**Purpose**: Mihon manga reader integration

**Key Methods**:
- `openInMangaReader(folder, onProgress)` - Export and launch
- `detectMihon()` - Check if Mihon installed
- `cleanupMangaReaderTemp(path)` - Remove temp files
- `setCustomTempFolderLocation(path)` - Configure temp location

**Flow**:
1. Check permissions
2. Detect Mihon installation
3. Create temp folder in custom location
4. Decrypt files with progress tracking
5. Launch Mihon (if installed)
6. Return temp path for cleanup

### BulkImportService
**Purpose**: Efficient folder import

**Key Methods**:
- `importFolder(folderPath, parentId, onProgress)` - Import folder
- `_scanFolder(path)` - Scan folder structure
- `_compareNatural(a, b)` - Natural sort comparison

**Features**:
- Recursive folder scanning
- Natural sort ordering
- Batch encryption (10 files per batch)
- Progress callbacks
- Memory efficient streaming

## 🚀 Performance Optimizations

### Memory Management
```dart
MemoryManagementService
├── Image cache: 50 images, 50MB max
├── Batch processing: 10 files per batch
├── Stream-based encryption
└── Progressive loading
```

### Hardware Acceleration
```dart
HardwareAccelerationService (Windows)
├── FVP integration for video
├── GPU-accelerated decoding
├── Reduced CPU usage
└── Smooth video playback
```

### Battery Awareness (Android)
```dart
BatteryAwarenessService
├── Detect low battery
├── Reduce background operations
├── Optimize encryption speed
└── Thermal protection
```

## 🔧 Build Configuration

### Android Build
```yaml
minSdkVersion: 23 (Android 6.0)
targetSdkVersion: 34 (Android 14)
compileSdkVersion: 34
versionName: 2.5.0
versionCode: 5
```

### Windows Build
```yaml
Platform: x64
Configuration: Release
FVP: Enabled
Inno Setup: 6.7.0
Output: LocalVault-x86_64-2.5.0+5-Installer.exe
```

### Dependencies
```yaml
Core:
- flutter: SDK
- isar: ^3.1.0+1 (Database)
- encrypt: ^5.0.1 (Encryption)
- path_provider: ^2.1.1 (File paths)

Platform-Specific:
- fvp: ^0.28.0 (Windows video)
- permission_handler: ^10.4.5 (Android permissions)
- uri_content: ^0.0.3 (Android SAF)

UI/UX:
- file_picker: ^5.5.0
- share_plus: ^7.1.0
- url_launcher: ^6.2.1
```

## 📱 Platform-Specific Features

### Windows
- FVP hardware-accelerated video playback
- Yomikiru manga reader integration
- Desktop context menus
- File picker dialogs
- Inno Setup installer

### Android
- Storage Access Framework (SAF) support
- Mihon/Tachiyomi integration
- Runtime permissions handling
- Custom temp folder locations
- Share functionality

## 🧪 Testing Checklist

### Functional Testing
- ✅ File encryption/decryption
- ✅ Folder import with structure preservation
- ✅ ZIP import (with/without password)
- ✅ ZIP export (with/without password)
- ✅ Search functionality
- ✅ Yomikiru integration (Windows)
- ✅ Mihon integration (Android)
- ✅ Progress dialogs
- ✅ Cleanup functionality

### Performance Testing
- ✅ Large file handling (>100MB)
- ✅ Bulk import (1000+ files)
- ✅ Memory usage (<500MB)
- ✅ Battery impact (Android)
- ✅ Startup time (<3 seconds)

### Security Testing
- ✅ Encryption strength (AES-256)
- ✅ Key derivation (PBKDF2)
- ✅ Secure password storage
- ✅ Temp file cleanup
- ✅ No plaintext leakage

## 🐛 Known Limitations

1. **Android Memory**: Password-protected ZIP import uses 1.2GB+ RAM
   - **Solution**: Use no-password ZIP (200MB RAM)

2. **Windows Icon Format**: Must be 3.00 format ICO
   - **Solution**: Use favicon.ico from icon generator

3. **Natural Sort**: Decimal numbers work (0.1, 0.2... 1, 2...)
   - **Confirmed**: Working as expected

4. **Temp Folder Cleanup**: Manual cleanup required
   - **By Design**: Prevents accidental data loss

## 📊 Performance Metrics

### Encryption Speed
- Small files (<1MB): ~50ms
- Medium files (1-10MB): ~200ms
- Large files (>10MB): ~2s

### Import Speed
- 100 images: ~30 seconds
- 500 images: ~2 minutes
- 1000 images: ~4 minutes

### Memory Usage
- Idle: ~100MB
- Active import: ~200-500MB
- Manga reading: ~300MB

## 🔐 Security Considerations

### Threat Model
- **Protected Against**:
  - Unauthorized file access
  - Data theft from device
  - Brute force attacks (PBKDF2)
  - Memory dumps (encrypted in RAM)

- **Not Protected Against**:
  - Device compromise (malware)
  - Keyloggers
  - Physical device access with password
  - Side-channel attacks

### Best Practices
1. Use strong master password (12+ characters)
2. Store recovery key offline
3. Enable device encryption
4. Regular backups to external storage
5. Cleanup temp folders after use

## 📝 Code Style Guidelines

### Dart/Flutter
- Follow official Dart style guide
- Use meaningful variable names
- Document public APIs
- Handle errors gracefully
- Use const constructors where possible

### File Organization
```
lib/
├── app/           # App configuration
├── db/            # Database setup
├── models/        # Data models
├── services/      # Business logic
├── ui/            # User interface
│   ├── auth/      # Authentication screens
│   ├── home/      # Home screen (Windows)
│   ├── mobile/    # Mobile home screen
│   ├── settings/  # Settings screens
│   └── viewers/   # File viewers
└── utils/         # Utility functions
```

## 🚀 Future Enhancements

### Planned Features
- [ ] Cloud backup integration (optional)
- [ ] Biometric authentication
- [ ] File versioning
- [ ] Shared vaults (multi-user)
- [ ] iOS support
- [ ] Linux support
- [ ] Web viewer (read-only)

### Performance Improvements
- [ ] Parallel encryption
- [ ] Incremental backups
- [ ] Smart caching
- [ ] Background sync

---

**Last Updated**: Version 2.5.0
**Maintained By**: Local Vault Development Team
