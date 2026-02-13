# Build Instructions for Local Vault v2.5.0

## 🚀 Quick Build (Recommended)

### Option 1: Using Build Script (Easiest)
1. Double-click `build_installer.bat`
2. Wait for build to complete
3. Find installer at: `build\windows\x64\installer\Release\LocalVault-x86_64-2.5.0+5-Installer.exe`

### Option 2: Manual Commands

**Windows Installer**:
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build installer
dart run inno_bundle:build --release
```

**Android APK**:
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release
```

---

## 📋 Version 2.5.0 Features

### What's New:
- ✅ Custom app icons for Windows and Android
- ✅ Hardware-accelerated video playback (Windows with FVP)
- ✅ Real-time progress dialogs for Yomikiru/Mihon integration
- ✅ Removed non-functional vault file (.vault) import/export
- ✅ ZIP import/export with password protection (fully functional)
- ✅ Natural sort algorithm for file ordering
- ✅ Comprehensive documentation (README, TECHNICAL_DOCUMENTATION, CHANGELOG)

### Platform-Specific:
- **Windows**: FVP for video, Yomikiru integration, Inno Setup installer
- **Android**: Native video player, Mihon integration, SAF support for Android 15+

---

## 📦 Output

**Windows Installer**: `build\windows\x64\installer\Release\LocalVault-x86_64-2.5.0+5-Installer.exe`

**Android APK**: `android\build\app\outputs\apk\release\app-release.apk`

**File Size**: ~55MB Windows / ~30MB Android

**What It Does**:
- Single .exe file users can double-click to install
- Installs to Program Files
- Creates Start Menu shortcut
- Creates Desktop shortcut
- Includes VC++ Redistributable automatically
- No certificate required
- No sandboxing (encryption works correctly)

---

## 🧪 Testing the Installer

### Test 1: Installation
1. Navigate to `build\windows\x64\installer\Release\`
2. Double-click `LocalVault-x86_64-2.5.0+5-Installer.exe`
3. Follow installation wizard
4. App should install to `C:\Program Files\LocalVault\`

### Test 2: Encryption Verification
1. Open installed app
2. Import some files
3. Export folder as ZIP with password
4. Try to open exported ZIP with 7-Zip
5. **Expected**: Should be encrypted/unreadable ✅

### Test 3: Comparison with EXE Build
1. Run app from `build\windows\x64\runner\Release\local_vault.exe`
2. Export folder as ZIP with password
3. Compare with installer version export
4. **Expected**: Both should be encrypted identically ✅

---

## 🔧 Prerequisites

### Required Software
1. **Flutter SDK** (already installed)
2. **Inno Setup** - Install with:
   ```powershell
   winget install -e --id JRSoftware.InnoSetup
   ```
   Or download from: https://jrsoftware.org/isdl.php

### Verify Installation
```bash
# Check Flutter
flutter doctor

# Check Inno Setup (should not error)
dart run inno_bundle:build --help
```

---

## 📊 Build Comparison

| Method | Output | Size | Certificate | Sandboxing | Encryption |
|--------|--------|------|-------------|------------|------------|
| EXE (flutter build) | Folder | ~50MB | No | No | ✅ Works |
| MSIX | .msix file | ~60MB | Yes | Yes | ❌ Issues |
| Inno Setup | .exe installer | ~55MB | No | No | ✅ Works |

**Winner**: Inno Setup ✅

---

## ⚠️ Important Notes

### App ID
The app ID in `pubspec.yaml` is:
```
6887eaf9-6a35-50a9-a882-2b63efe063bc
```

**NEVER CHANGE THIS ID** after first deployment!

If you change it, users will see the update as a different app and will need to manually uninstall the old version.

### Windows SmartScreen
First-time users may see "Windows protected your PC" warning.

**This is normal** for unsigned installers.

**Users can bypass**: Click "More info" → "Run anyway"

**To remove warning**: Purchase code signing certificate ($200-400/year) - optional, not required.

---

## 🎯 Distribution

### Upload Installer To:
- GitHub Releases
- Your website
- Google Drive / Dropbox
- Direct download link

### Files to Distribute:
- **Windows**: `LocalVault-x86_64-2.5.0+5-Installer.exe` (from `build\windows\x64\installer\Release\`)
- **Android**: `app-release.apk` (from `android\build\app\outputs\apk\release\`)

### User Instructions:

**Windows**:
1. Download `LocalVault-x86_64-2.5.0+5-Installer.exe`
2. Double-click to install
3. Follow installation wizard
4. Done!

**Android**:
1. Download `app-release.apk`
2. Enable "Install from Unknown Sources" in Settings
3. Tap APK file to install
4. Done!

---

## 🔄 Updating the App

### For New Versions:
1. Update version in `pubspec.yaml`:
   ```yaml
   version: 2.5.0+5  # Current version
   ```

2. Build new installers:
   
   **Windows**:
   ```bash
   dart run inno_bundle:build --release
   ```
   
   **Android**:
   ```bash
   flutter build apk --release
   ```

3. Distribute new installers

### For Users:
- Download new installer
- Run it (will automatically update existing installation)
- Old version is replaced
- Settings and data are preserved

---

## 🐛 Troubleshooting

### "Inno Setup not found"
**Solution**: Install Inno Setup first
```powershell
winget install -e --id JRSoftware.InnoSetup
```

### "Couldn't open include file Icelandic.isl" (or other language files)
**Solution**: Already fixed! The app now only uses English language.
If you still see this error, run:
```bash
flutter clean
flutter pub get
dart run inno_bundle:build --release
```

### "Cannot find file or app" error (Code 2) when launching installed app
**Solution**: Already fixed! The `name` parameter now matches the actual .exe filename.
If you still see this error, rebuild:
```bash
dart run inno_bundle:build --release
```

### Build fails
**Solution**: Clean and rebuild
```bash
flutter clean
flutter pub get
dart run inno_bundle:build --release
```

### Installer doesn't work
**Solution**: Make sure you built with `--release` flag

### Can't find installer file
**Solution**: Check exact paths:

**Windows**:
```
build\windows\x64\installer\Release\LocalVault-x86_64-2.5.0+5-Installer.exe
```

**Android**:
```
android\build\app\outputs\apk\release\app-release.apk
```

---

## 📝 Configuration

Current configuration in `pubspec.yaml`:

```yaml
inno_bundle:
  id: 6887eaf9-6a35-50a9-a882-2b63efe063bc
  publisher: Local Vault Developer
  name: local_vault  # Must match the actual .exe file name
  display_name: Local Vault  # Display name for shortcuts
  description: Secure encrypted file storage and manga reading app
  languages:
    - english  # Only English to avoid missing language file errors
  install_dir_name: LocalVault
  start_menu_folder: Local Vault
  create_desktop_shortcut: true
  allow_user_install_dir: true
```

### Optional Customizations:
- Add custom icon: `icon_path: assets/icon.ico`
- Add license: `license_path: LICENSE.txt`
- Change install directory: `install_dir_name: YourName`

---

## ✅ Advantages Over MSIX

✅ No certificate required  
✅ No sandboxing issues  
✅ Encryption works correctly  
✅ Traditional Windows installer  
✅ Works on Windows 7+  
✅ Smaller file size  
✅ Easier for users  
✅ Automatic VC++ Redistributable  

---

## 🎉 You're Ready!

Run `build_installer.bat` to create your first installer!

