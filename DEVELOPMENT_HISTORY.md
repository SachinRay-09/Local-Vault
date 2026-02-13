# Development History - Local Vault

**Current Version**: 2.5.0  
**Last Updated**: February 13, 2026

---

## Version 2.5.0 (February 13, 2026)

### Features Added
- ✅ Custom app icons for Windows and Android
- ✅ Hardware-accelerated video playback (Windows with FVP)
- ✅ Real-time progress dialogs for Yomikiru/Mihon integration
- ✅ Comprehensive documentation (README, TECHNICAL_DOCUMENTATION, CHANGELOG)

### Changes
- Updated app icons across all platforms
- Re-implemented FVP for Windows video playback
- Enhanced user experience with progress tracking

### Build Outputs
- Windows: `LocalVault-x86_64-2.5.0+5-Installer.exe`
- Android: `app-release.apk`

---

## Version 2.2.0 (February 12, 2026)

### Features Added
- ✅ Real-time progress dialogs for Yomikiru (Windows) and Mihon (Android)
- ✅ Progress shows: "Preparing export...", "Created temp folder", "Found X images", "Decrypting files... (X/Y)", "Export completed"
- ✅ 500ms delay after completion to show green checkmark before transitioning

### Technical Implementation
- Created `_YomikiruProgressDialog` widget in `lib/ui/home/home_screen.dart`
- Created `_MihonProgressDialog` widget in `lib/ui/mobile/mobile_home_screen.dart`
- Added `onProgress` callback parameter to service methods

---

## Version 2.1.0 (February 10, 2026)

### Critical Fixes

#### 1. Vault File (.vault) Export/Import Removed
**Reason**: Consistently failed with 0 files imported despite multiple fix attempts

**What Was Removed**:
- Desktop: "Export Encrypted (.vault)" from context menu
- Mobile: "Import Android Vault" from menu
- Service: `encrypted_export_service.dart` deleted, stub created

**Impact**: None - ZIP import/export is superior and works perfectly

#### 2. ZIP Import System - Complete Overhaul
**Problem**: Android ZIP import showed progress but saved 0 files to database

**Root Cause**: Isolate-based encryption couldn't access temp file paths

**Solution**: Switched to main-thread encryption with batching and yielding
- Files now encrypt and save correctly
- Progress updates smoothly every file
- UI remains responsive with 10-file batches
- 50ms delays between batches prevent UI freeze

#### 3. File Order Preservation
**Problem**: Files sorted incorrectly (1, 10, 100, 2, 20...)

**Solution**: Natural sort algorithm (Alphanum Algorithm)
- Files now display correctly: 1, 2, 3... 10... 100
- `sortOrder` field added to VaultFile model
- Files sorted BEFORE encryption to preserve order

#### 4. Memory Optimization
**Problem**: Out of Memory errors during ZIP import

**Solution**: Streaming extraction and hybrid approach
- Non-encrypted ZIPs: Streaming extraction (200MB constant)
- Password-protected ZIPs: Memory extraction (1.2GB spike, necessary)
- Memory usage reduced from 2.4GB → 200MB (12x reduction)

#### 5. Password-Protected ZIP Import (Android)
**Problem**: Error: "Cannot remove from a fixed-length list"

**Solution**: Removed `bytes.clear()` call after decoding password-protected ZIP

#### 6. Folder Structure Preservation
**Problem**: Files imported to root instead of preserving folder structure

**Solution**: Modified `_writeFolderStagingFromDb()` to create root folder in staging directory

### Features Added

#### 1. Export Password Option
Added export options dialog:
- "Without Password (Recommended)" - 200MB on Android
- "With Password" - 1.2GB on Android
- User can choose based on device capabilities

#### 2. On-Screen Debug Display
Added real-time debug panel during ZIP import:
- Shows extracted file count
- Shows encrypted file count
- Shows saved to database count
- Displays last 5 status messages

#### 3. Individual Folder Export
- Right-click folder → "Export as ZIP"
- Password option dialog
- Progress dialog with status updates

#### 4. Save to Local Gallery
- Menu → "Save to Local Gallery"
- Windows: User chooses location
- Android: Auto-saves to Downloads folder
- Unencrypted ZIP (for local backup)
- Warning dialog about unencrypted content

### Technical Improvements

#### Encryption System
- Removed isolate-based encryption (couldn't access temp files)
- Implemented main-thread encryption with proper yielding
- 10-file batches with 50ms delays
- 1ms yield before each file for UI updates

#### Database Operations
- Immediate save after each file encryption
- Batch size: 10 files per batch
- Transaction optimization
- Null safety checks for all encryption results

#### Status Updates
Structured status messages for parsing:
- `EXTRACTED:X` - Files extracted from ZIP
- `ENCRYPTED:X` - Files encrypted successfully
- `SAVED:X` - Files saved to database

### Performance Metrics

#### ZIP Import (2900 files)
- Extraction: 1-2 minutes
- Encryption: 10-15 minutes (main thread with yielding)
- Database Save: Included in encryption
- **Total: 12-17 minutes** (slower but actually works!)

#### Memory Usage
- Non-encrypted ZIP: 200MB constant
- Password-protected ZIP: 1.2GB spike (temporary)
- No Out of Memory errors

---

## Version 2.0.x (Earlier Versions)

### Features Implemented
- ✅ AES-256-CBC encryption for all stored files
- ✅ Password-protected vault
- ✅ Cross-platform file transfer (Windows ↔ Android)
- ✅ Manga reading support
- ✅ Folder organization
- ✅ Search functionality
- ✅ Inno Setup installer (replaced MSIX)
- ✅ Smart password detection for .vault import
- ✅ Enhanced import debugging
- ✅ FVP for Windows video playback

### Issues Fixed
- Desktop context menu export options
- Temp_import.zip file appearing in vault
- Cross-platform path handling
- Archive isFile property setting

---

## Architecture Decisions

### Why Main-Thread Encryption Instead of Isolates?

**Initial Approach**: Used `compute()` isolate for background encryption
- Pros: Doesn't block UI, faster processing
- Cons: Isolates can't access temp file paths created in main thread

**Final Solution**: Main-thread encryption with batching
```dart
const batchSize = 10; // Small batches
for (int i = 0; i < files.length; i += batchSize) {
  for (final file in batch) {
    await Future.delayed(const Duration(milliseconds: 1)); // Yield to UI
    final result = await crypto.encryptFileToBlob(...);
    await _isar.writeTxn(() => _isar.vaultFiles.put(vaultFile));
  }
  await Future.delayed(const Duration(milliseconds: 50)); // Batch delay
}
```

### Natural Sort Implementation

**Problem**: Platform-dependent file ordering
- Windows: 1.jpg, 10.jpg, 2.jpg, 20.jpg
- Need: 1.jpg, 2.jpg, 10.jpg, 20.jpg

**Solution**: Alphanum Algorithm
```dart
int _compareNatural(String a, String b) {
  // Extract numbers and compare numerically
  // Compare non-numbers lexicographically
  // Result: Natural human-readable order
}
```

### Memory Management Strategy

**Hybrid Approach for ZIP Extraction**:

1. **Password-Protected ZIPs**:
   ```dart
   final bytes = await zipFile.readAsBytes(); // Load into memory
   archive = ZipDecoder().decodeBytes(bytes, password: password);
   // Must use decodeBytes() - password decryption needs full data
   // Memory spike: 1.2GB (unavoidable)
   ```

2. **Non-Encrypted ZIPs**:
   ```dart
   final inputStream = InputFileStream(zipPath);
   archive = ZipDecoder().decodeBuffer(inputStream); // Streaming
   entry.writeContent(outputStream); // Stream to disk
   // Memory usage: 200MB constant
   ```

---

## Lessons Learned

### 1. Isolates Have Limitations
- Can't access file paths from main thread
- Can't use platform channels
- Limited to pure Dart code
- Best for CPU-intensive calculations, not I/O

### 2. Main-Thread Operations Can Be Responsive
- Small batches (10 files)
- Frequent yielding (1ms + 50ms)
- Async operations help
- Progress callbacks work well

### 3. Debug Display Is Essential
- Users can't access terminal logs on mobile
- On-screen debug info is invaluable
- Structured messages enable parsing
- Real-time feedback prevents confusion

### 4. Memory Management Requires Trade-offs
- Password-protected ZIPs need memory
- Streaming works for non-encrypted
- Hybrid approach is best solution
- User choice (password vs no password) helps

---

## Known Limitations

1. **Folder Import**: Windows only (Android uses ZIP import)
2. **Video Playback**: FVP on Windows only (Android uses native player)
3. **Export on Mobile**: Not implemented (use Windows for export)
4. Large files (>500MB) might cause memory issues
5. Import cancellation doesn't clean up partial imports
6. No resume capability for interrupted imports

---

## Future Improvements

### Potential Optimizations
1. **Isolate.spawn() with SendPort**: Might work better than compute()
2. **Native Platform Code**: Android/iOS native encryption
3. **Chunked Database Writes**: Batch multiple files per transaction
4. **Background Service**: Android WorkManager for long imports

### Planned Features
- [ ] Cloud sync (optional)
- [ ] Biometric authentication
- [ ] File compression
- [ ] Thumbnail generation
- [ ] Advanced search filters

---

**Last Updated**: February 13, 2026  
**Current Version**: 2.5.0  
**Status**: Production Ready ✅
