# User Guide - Local Vault

Complete guide for using Local Vault v3.0.0 to securely store and manage your private media.

---

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Basic Operations](#basic-operations)
- [Advanced Features](#advanced-features)
- [Manga Reader Integration](#manga-reader-integration)
- [Import & Export](#import--export)
- [Settings](#settings)
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
- **NO PASSWORD RECOVERY** — if you forget it, your data is permanently inaccessible
- This is by design for maximum security

**Your password is cryptographically required to access your vault.** The vault's Data Encryption Key (DEK) is wrapped by a Key Encryption Key derived from your password via PBKDF2-HMAC-SHA256 (200,000 iterations). Forgetting your password means permanent loss of access.

**Export a recovery key** (Settings → Security → Export Recovery Key) before you rely on this vault for important data.

**Example Strong Password**: `MyM@nga2024!Vault`

#### 3. Grant Permissions (Android)

- Storage Access: required for importing files
- Optional: disable internet access in device app settings for extra privacy

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
- Folders sort naturally: 1, 2, 10 (not 1, 10, 2)

### Importing Files

#### Import Folder

**Windows:**
1. Menu → Import Folder
2. Paste folder path (e.g., `D:\Manga\MyCollection`)
3. Press Enter
4. Wait for encryption progress

**Android:**
1. Menu → Import Folder
2. Navigate to folder in file picker
3. Select folder
4. Wait for encryption progress

**What Happens:**
- All files in folder are encrypted one at a time (streaming pipeline)
- Folder structure is preserved
- Original files remain untouched
- Progress shown in real-time
- If import is interrupted, it resumes from the last committed file on next attempt

#### Import ZIP

**Windows/Android:**
1. Menu → Import ZIP
2. Select or paste ZIP file path
3. Enter password if ZIP is encrypted (leave blank if not)
4. Wait for extraction and encryption

**Supported:**
- Plain ZIP files
- Password-protected ZIP files
- Large ZIP files (1 GB+)

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
4. **WARNING**: This is permanent and cannot be undone

### Multi-Select Operations

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

### Searching

1. Tap search icon in top bar
2. Type folder or file name
3. Results filter in real-time
4. Tap result to open

---

## Advanced Features

### Natural Sorting

Folders sort correctly with numbers automatically — no configuration needed:
- Before: 1, 10, 2, 20, 3
- After: 1, 2, 3, 10, 20

### Viewing Files

**Images:**
- Tap image to view full screen
- Swipe to navigate between images
- Pinch to zoom

**Videos:**
- Tap video to play
- Hardware acceleration on Windows
- Standard video player on Android

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
4. **IMPORTANT**: Always cleanup — temp files are unencrypted!

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
   - **With Password**: more secure, uses more memory
   - **Without Password**: faster, less memory
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

### Transfer Between Devices

**Windows → Android:**
1. Export folder as ZIP on Windows (no password recommended for ease)
2. Transfer ZIP to Android (USB, cloud, etc.)
3. In Android app: Import ZIP
4. Enter password if used

**Android → Windows:**
1. Export as ZIP on Android via right-click / long-press → Export as ZIP
2. Transfer ZIP to Windows
3. In Windows app: Import ZIP

---

## Settings

### Password

Change your master password at: Settings → Security → Change Password.

The app re-wraps your vault DEK under a new KEK — your stored files are not re-encrypted, only the key wrapper changes.

### Theme

Settings → Appearance → choose System / Light / Dark.

### Screenshot Blocking (Android)

Settings → Security → Block Screenshots — prevents the system screenshot tool and recent-apps thumbnail from capturing vault contents. Default is OFF.

---

## Troubleshooting

### Common Issues

#### "Import Taking Too Long"

Large imports are fast on modern hardware — see [docs/PERFORMANCE.md](docs/PERFORMANCE.md) for real benchmark numbers. If an import seems stuck, don't close the app; it will resume from where it left off if interrupted.

#### "Invalid Depfile" Warnings

These warnings are harmless Flutter build cache messages. If a build fails, run `flutter clean`.

#### "Out of Memory" During Export

- Export without password (uses much less memory)
- Close other apps
- Export smaller folders separately

#### "Yomikiru/Mihon Not Launching"

- Verify the manga reader is installed
- Check temp folder path in success dialog
- Manually open the manga reader and navigate to the temp folder path shown

#### "Can't Import ZIP"

- Check the ZIP is not corrupted
- Try without password first
- Ensure enough storage space
- Check file permissions (Android)

#### "Forgot Password"

There is no password recovery. Your data is permanently locked. This is intentional — no backdoor means true privacy. Always keep a note of your password in a safe place, and export a recovery key from Settings → Security.

### Performance Issues

#### Slow Import
- Close other apps
- Restart device
- Import smaller batches
- Check [docs/PERFORMANCE.md](docs/PERFORMANCE.md) for expected times on tested hardware

#### App Crashes
- Update to latest version
- Clear app cache
- Reinstall app (vault data is preserved)

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

2. **Export a Recovery Key**
   - Settings → Security → Export Recovery Key
   - Store the recovery key somewhere physically safe

3. **Device Security**
   - Use device lock screen (PIN/pattern/fingerprint)
   - Don't root/jailbreak device
   - Keep OS updated

4. **Temp Folder Cleanup**
   - Always cleanup after manga reading
   - Temp files are unencrypted
   - Use "Clear Cache" regularly

5. **Regular Backups**
   - Export vault periodically
   - Store backup on external drive
   - Test backup by importing on another device

### Organization

1. **Folder Structure**
   - Use clear, descriptive names
   - Group related content
   - Use numeric prefixes for order: "01 - Series Name", "02 - Series Name"
   - Don't nest too deeply (3–4 levels max)

2. **Import Strategy**
   - Import in batches for very large libraries
   - Close other apps during large imports

3. **Storage Management**
   - Keep 20% storage free
   - Delete unused content
   - Export old content to external drive

---

## Keyboard Shortcuts (Windows)

- `Ctrl + F` — Search
- `Ctrl + N` — New Folder
- `Ctrl + I` — Import Folder
- `Delete` — Delete Selected
- `F2` — Rename
- `Ctrl + A` — Select All (in multi-select mode)
- `Esc` — Exit multi-select mode

---

## FAQ

**Q: Is my data safe?**
A: Yes. AES-256-GCM is industry-standard encryption. Even if someone has your device storage, they cannot access your files without the password.

**Q: Can I recover my password?**
A: No. This is by design for maximum security. Export a recovery key from Settings → Security before you rely on the vault for important data.

**Q: Does this app use internet?**
A: No. Everything is 100% local. You can disable internet access for the app.

**Q: Can I sync between devices?**
A: No cloud sync. Use Export/Import to manually transfer between devices.

**Q: Is this app free?**
A: One-time purchase. No subscriptions, no ads.

**Q: Can I share files with others?**
A: Export as ZIP and share. The recipient needs Local Vault to decrypt password-protected exports.

**Q: What happens if I uninstall?**
A: Vault data is deleted. Export a backup first!

**Q: Can I use on iOS/Mac?**
A: Not currently. Windows and Android only.

**Q: Is source code available?**
A: Check the GitHub repository for details.

---

## Support

- **Email**: shadow99810@gmail.com
- **GitHub Issues**: Report bugs and request features
- **Documentation**: [README.md](README.md), [DEVELOPMENT.md](DEVELOPMENT.md), [docs/PERFORMANCE.md](docs/PERFORMANCE.md)

---

**Keep your media private. 🔒**
