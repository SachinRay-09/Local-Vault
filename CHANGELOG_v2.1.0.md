# Local Vault v2.1.0 - ZIP Import Fix & Performance Improvements

## Release Date
February 8, 2026

## Critical Fixes

### ZIP Import System - Complete Overhaul
**Problem**: Android ZIP import showed progress but saved 0 files to database
- Extracted: 2902 ✓
- Encrypted: 0 ✗
- Saved to DB: 0 ✗

**Root Cause**: Isolate-based encryption couldn't access temp file paths

**Solution**: Switched to main-thread encryption with batching and yielding
- Files now encrypt and save correctly
- Progress updates smoothly every file
- UI remains responsive with 10-file batches
- 50ms delays between batches prevent UI freeze

### File Order Preservation
**Problem**: Files sorted incorrectly (1, 10, 100, 2, 20...)

**Solution**: Natural sort algorithm (Alphanum Algorithm)
- Files now display correctly: 1, 2, 3... 10... 100
- `sortOrder` field added to VaultFile model
- Files sorted BEFORE encryption to preserve order
- Works for all image formats (JPEG, PNG, WebP, GIF, BMP, SVG)

### Memory Optimization
**Problem**: Out of Memory errors during ZIP import

**Solution**: Streaming extraction and hybrid approach
- Non-encrypted ZIPs: Streaming extraction (200MB constant)
- Password-protected ZIPs: Memory extraction (1.2GB spike, necessary)
- Memory usage reduced from 2.4GB → 200MB (12x reduction)

### Export Password Option
**Problem**: Android Out of Memory when importing password-protected ZIPs

**Solution**: Added export options dialog
- "Without Password (Recommended)" - 200MB on Android
- "With Password" - 1.2GB on Android
- User can choose based on device capabilities

## New Features

### On-Screen Debug Display
Added real-time debug panel during ZIP import:
- Shows extracted file count
- Shows encrypted file count
- Shows saved to database count
- Displays last 5 status messages
- Helps diagnose import issues instantly

### Progress Tracking
Enhanced progress dialog with:
- File-by-file progress updates
- Current filename display
- Time estimation
- Percentage completion
- Debug information panel

## Technical Improvements

### Encryption System
- Removed isolate-based encryption (couldn't access temp files)
- Implemented main-thread encryption with proper yielding
- 10-file batches with 50ms delays
- 1ms yield before each file for UI updates
- Progress callbacks trigger setState() for smooth updates

### Database Operations
- Immediate save after each file encryption
- Batch size: 10 files per batch
- Transaction optimization
- Null safety checks for all encryption results
- Try-catch for database write failures

### Status Updates
Structured status messages for parsing:
- `EXTRACTED:X` - Files extracted from ZIP
- `ENCRYPTED:X` - Files encrypted successfully
- `SAVED:X` - Files saved to database

## Performance Metrics

### ZIP Import (2900 files)
- Extraction: 1-2 minutes
- Encryption: 10-15 minutes (main thread with yielding)
- Database Save: Included in encryption
- **Total: 12-17 minutes** (slower but actually works!)

### Memory Usage
- Non-encrypted ZIP: 200MB constant
- Password-protected ZIP: 1.2GB spike (temporary)
- No Out of Memory errors

### UI Responsiveness
- Progress updates every file
- No UI freeze
- Smooth animations maintained
- Cancel button remains responsive

## Breaking Changes
None - All changes are internal improvements

## Migration Notes
No migration needed - existing vaults work without changes

## Known Limitations
- Password-protected ZIPs require 1.2GB memory spike (unavoidable)
- Main-thread encryption is slower than isolate would be (but isolate doesn't work)
- Large imports (2000+ files) take 10-15 minutes

## Files Modified
- `lib/services/saf_zip_import_service.dart` - Complete rewrite of encryption logic
- `lib/ui/mobile/mobile_home_screen.dart` - Added debug display panel
- `lib/models/vault_file.dart` - Added sortOrder field
- `lib/services/vault_repository.dart` - Updated queries to use sortOrder

## Upgrade Instructions
1. Uninstall previous version
2. Install v2.1.0 APK
3. Import your vaults normally
4. ZIP imports now work correctly with progress display

## Credits
All fixes based on real-world testing and user feedback. Special thanks to web research on Flutter isolate limitations and Isar database persistence issues.
