# User Guide - Local Vault

Complete guide for using Local Vault to securely store and manage your private media.

---

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Basic Operations](#basic-operations)
- [Advanced Features](#advanced-features)
- [Manga Reader Integration](#manga-reader-integration)
- [Import & Export](#import--export)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## Getting Started

### First Time Setup

#### 1. Installation

**Windows:**
1. Download `LocalVault-x86_64-[version]-Installer.exe`
2. Run installer (may need Administrator rights)
3. Follow installation wizard
4. Launch from Start Menu or Desktop shortcut

**Android:**
1. Download `app-release.apk`
2. Settings → Security → Enable "Install from Unknown Sources"
3. Open APK file and tap "Install"
4. Grant storage permissions when prompted
5. Launch "Local Vault" from app drawer

#### 2. Create Master Password

**IMPORTANT**: Choose a strong password you'll remember!

- Minimum 8 characters
- Mix of uppercase, lowercase, numbers, symbols
- **NO PASSWORD RECOVERY** - If you forget it, your data is lost forever
- This is by design for maximum security

Note: Your password unlocks the app. The actual vault encryption key is stored separately in the OS keystore (Windows Credential Manager / Android Keystore). Security questions allow resetting your login password only — they cannot recover your encrypted data if the key is lost.

**Example Strong Password**: `MyM@nga2024!Vault`

#### 3. Grant Permissions (Android)

- Storage Access: Required for importing files
- Optional: Disable internet access in app settings for extra privacy

---

## Basic Operations

### Creating Folders

**Windows:**
1. Click "Create Folder" button in top navbar
2. Enter folder name
3. Press Enter or click OK

**Android:**
1. Tap "+" button
2. Select "New Folder"
3. Enter folder name
4. Tap "Create"

**Tips:**
- Use numeric prefixes for ordering: "01 - Chapter 1", "02 - Chapter 2"
- Folders now sort naturally: 1, 2, 10 (not 1, 10, 2)

### Importing Files

#### Import Folder

**Windows:**
1. Menu → Import Folder
2. Paste folder path (e.g., `D:\Manga\MyCollection`)
3. Press Enter
4. Wait for encryption progress (may take time for large folders)

**Android:**
1. Menu → Import Folder
2. Navigate to folder in file picker
3. Select folder
4. Wait for encryption progress

**What Happens:**
- All files in folder are encrypted
- Folder structure is preserved
- Original files remain untouched
- Progress shown in real-time

#### Import ZIP

**Windows/Android:**
1. Menu → Import ZIP
2. Select or paste ZIP file path
3. Enter password if ZIP is encrypted (leave blank if not)
4. Wait for extraction and encryption

**Supported:**
- Plain ZIP files
- Password-protected ZIP files
- Large ZIP files (1GB+, but takes time)

### Organizing Files

#### Rename Folder
1. Right-click (Windows) or long-press (Android) on folder
2. Select "Rename"
3. Enter new name
4. Confirm

#### Move Folder
1. Right-click or long-press on folder
2. Select "Move"
3. Choose destination folder (or root)
4. Confirm

#### Delete Folder
1. Right-click or long-press on folder
2. Select "Delete"
3. Confirm deletion
4. **WARNING**: This is permanent!

### Multi-Select Operations

**New in v2.5.2!**

#### Select Multiple Folders
1. Long-press on first folder (enters selection mode)
2. Tap additional folders to select
3. Selected count shows in top bar

#### Batch Move
1. Select multiple folders
2. Tap "Move" icon in top bar
3. Choose destination
4. All selected folders move at once

#### Batch Delete
1. Select multiple folders
2. Tap "Delete" icon in top bar
3. Confirm deletion
4. All selected folders deleted

### Searching

1. Tap search icon in top bar
2. Type folder or file name
3. Results filter in real-time
4. Tap result to open

---

## Advanced Features

### Natural Sorting

Folders now sort correctly with numbers:
- Before: 1, 10, 2, 20, 3
- After: 1, 2, 3, 10, 20

Works automatically - no configuration needed!

### Viewing Files

**Images:**
- Tap image to view full screen
- Swipe to navigate between images
- Pinch to zoom

**Videos:**
- Tap video to play
- Hardware acceleration on Windows
- Standard video player on Android

### Tags (Coming Soon)

Tag files for better organization:
- Add multiple tags per file
- Search by tags
- Filter by tags

---

## Manga Reader Integration

### Yomikiru (Windows)

#### Setup
1. Download Yomikiru from [GitHub](https://github.com/mienaiyami/yomikiru/releases)
2. Install Yomikiru
3. Local Vault will auto-detect it

#### Usage
1. Right-click manga folder
2. Select "Open in Yomikiru"
3. Progress dialog shows decryption status
4. Yomikiru launches automatically
5. Read your manga!

#### After Reading
1. Close Yomikiru
2. In Local Vault, tap "Cleanup" button
3. Or use "Clear Cache" to remove temp files
4. **IMPORTANT**: Always cleanup to free space!

#### Manual Opening
If auto-launch fails:
1. Copy temp folder path from success dialog
2. Open Yomikiru manually
3. Navigate to temp folder path
4. Read manga

### Mihon/Tachiyomi (Android)

#### Setup
1. Install Mihon from [official source](https://mihon.app)
2. Local Vault will auto-detect it

#### Usage
1. Long-press manga folder
2. Select "Open in Mihon"
3. Progress dialog shows decryption
4. Mihon launches (may need manual open)
5. Navigate to temp folder if needed

#### Recommended Temp Location
Menu → Manga Reader Settings → Set to:
`/storage/emulated/0/Mihon/local`

#### After Reading
1. Close Mihon
2. In Local Vault, use cleanup dialog
3. Remove temp files to free space

---

## Import & Export

### Export Folder as ZIP (Windows)

1. Right-click folder
2. Select "Export as ZIP"
3. Choose password protection:
   - **With Password**: More secure, uses more memory (1.2GB+)
   - **Without Password**: Faster, less memory (200MB)
4. Select save location
5. Wait for encryption and compression

**Use Cases:**
- Backup to external drive
- Transfer to another device
- Share with trusted person

### Export All (Windows)

1. Menu → Export All
2. Choose password protection
3. Select save location
4. Creates single ZIP of entire vault
5. **WARNING**: May take long time for large vaults!

### Save to Gallery (Android)

1. Menu → Save to Local Gallery
2. Creates unencrypted ZIP in Downloads folder
3. **WARNING**: Files are NOT encrypted!
4. Use only for temporary backup

### Transfer Between Devices

**Windows → Android:**
1. Export folder as ZIP (no password recommended)
2. Transfer ZIP to Android (USB, cloud, etc.)
3. In Android app: Import ZIP
4. Enter password if used

**Android → Windows:**
1. Use "Save to Gallery" to create ZIP
2. Transfer ZIP to Windows
3. In Windows app: Import ZIP

---

## Troubleshooting

### Common Issues

#### "Import Taking Too Long"

**Cause**: Encryption is CPU-intensive

**Solution**:
- Large files (1GB+) take 5-10 minutes
- This is normal - app is encrypting your data
- Don't close app during import
- Use memory optimizer if needed

**Expected Times:**
- 100MB folder: 1-2 minutes
- 500MB folder: 3-5 minutes
- 1.5GB folder: 8-12 minutes

#### "Invalid Depfile" Warnings

**Cause**: Flutter build cache issue

**Solution**:
- These warnings are harmless
- Build will complete successfully
- If build fails, run: `flutter clean`

#### "Out of Memory" During Export

**Cause**: Password-protected ZIP uses more memory

**Solution**:
- Export without password (uses 200MB vs 1.2GB+)
- Close other apps
- Use memory optimizer
- Export smaller folders separately

#### "Yomikiru/Mihon Not Launching"

**Cause**: App not installed or not detected

**Solution**:
- Verify manga reader is installed
- Check temp folder path in success dialog
- Manually open manga reader
- Navigate to temp folder path shown

#### "Can't Import ZIP"

**Cause**: Various reasons

**Solutions**:
- Check ZIP is not corrupted
- Try without password first
- Ensure enough storage space
- Try smaller ZIP files
- Check file permissions (Android)

#### "Forgot Password"

**Cause**: No password recovery by design

**Solution**:
- **There is NO solution**
- Your data is permanently locked
- This is intentional for security
- Always remember your password!

### Performance Issues

#### Slow Import
- Close other apps
- Restart device
- Check available RAM
- Import smaller batches

#### App Crashes
- Update to latest version
- Clear app cache
- Reinstall app (vault data preserved)
- Check device meets minimum requirements

#### Storage Full
- Delete unused folders
- Export and remove old content
- Check device storage settings
- Use external storage (Android)

---

## Best Practices

### Security

1. **Strong Password**
   - 12+ characters
   - Mix of uppercase, lowercase, numbers, symbols
   - Don't use common words or patterns
   - Don't share with anyone

2. **Device Security**
   - Use device lock screen (PIN/pattern/fingerprint)
   - Don't root/jailbreak device
   - Keep OS updated
   - Use antivirus (optional)

3. **Temp Folder Cleanup**
   - Always cleanup after manga reading
   - Temp files are unencrypted!
   - Use "Clear Cache" regularly
   - Check temp folder location

4. **Regular Backups**
   - Export vault monthly
   - Store backup on external drive
   - Keep backup in safe location
   - Test backup by importing

### Organization

1. **Folder Structure**
   - Use clear, descriptive names
   - Group related content
   - Use numeric prefixes for order
   - Don't nest too deeply (3-4 levels max)

2. **Naming Convention**
   - "01 - Series Name"
   - "02 - Series Name"
   - Consistent format across vault

3. **Tags** (when available)
   - Tag by genre, artist, series
   - Use consistent tag names
   - Don't over-tag

### Performance

1. **Import Strategy**
   - Import in batches (500MB at a time)
   - Close other apps during import
   - Use wired connection for large transfers
   - Import during off-hours

2. **Memory Management**
   - Use memory optimizer for large operations
   - Close app when not in use
   - Clear cache regularly
   - Restart device weekly

3. **Storage Management**
   - Keep 20% storage free
   - Delete unused content
   - Export old content to external drive
   - Monitor storage usage

---

## Keyboard Shortcuts (Windows)

- `Ctrl + F` - Search
- `Ctrl + N` - New Folder
- `Ctrl + I` - Import Folder
- `Delete` - Delete Selected
- `F2` - Rename
- `Ctrl + A` - Select All (in multi-select mode)
- `Esc` - Exit multi-select mode

---

## FAQ

**Q: Is my data safe?**  
A: Yes. AES-256 encryption is industry-standard and strong. Even if someone steals your device, they can't access your files without the password.

**Q: Can I recover my password?**  
A: No. This is by design for maximum security. No backdoors = true privacy.

**Q: Does this app use internet?**  
A: No. Everything is 100% local. You can disable internet access for the app.

**Q: Can I sync between devices?**  
A: No cloud sync. Use Export/Import to manually transfer.

**Q: Why is import so slow?**  
A: Encryption is CPU-intensive. Large files take time to encrypt securely.

**Q: Is this app free?**  
A: One-time purchase. No subscriptions, no ads.

**Q: Can I share files with others?**  
A: Export as ZIP and share. Recipient needs Local Vault to decrypt.

**Q: What happens if I uninstall?**  
A: Vault data is deleted. Export backup first!

**Q: Can I use on iOS/Mac?**  
A: Not yet. Currently Windows and Android only.

**Q: Is source code available?**  
A: Check GitHub repository for details.

---

## Support

Need help?

- **Email**: shadow99810@gmail.com
- **GitHub Issues**: Report bugs and request features
- **Documentation**: Check README.md and DEVELOPMENT.md

---

**Enjoy your private media sanctuary! 🔒**
