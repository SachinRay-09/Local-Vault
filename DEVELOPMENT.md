# Development Guide - Local Vault

Complete guide for setting up the development environment and building Local Vault from source.

---

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Setup](#environment-setup)
- [Project Structure](#project-structure)
- [Building](#building)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

#### 1. Flutter SDK
```bash
# Download Flutter SDK
https://docs.flutter.dev/get-started/install

# Verify installation
flutter doctor
```

**Required Version**: Flutter 3.2.6 or higher

#### 2. Dart SDK
Included with Flutter SDK (Dart 3.2.6+)

#### 3. Platform-Specific Tools

**For Windows Development:**
- Visual Studio 2022 (Community Edition or higher)
  - Desktop development with C++ workload
  - Windows 10 SDK
- Inno Setup 6 (for installer creation)
  - Download: https://jrsoftware.org/isdl.php

**For Android Development:**
- Android Studio (latest stable)
- Android SDK (API 26+)
- Android NDK
- Java JDK 11 or higher

#### 4. Git
```bash
# Install Git
https://git-scm.com/downloads

# Verify
git --version
```

---

## Environment Setup

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/local_vault.git
cd local_vault
```

### 2. Install Dependencies

```bash
# Get Flutter packages
flutter pub get

# Generate code (for Isar database)
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. Configure IDE

**VS Code:**
```bash
# Install extensions
- Flutter
- Dart
- Flutter Intl (optional)
```

**Android Studio:**
```bash
# Install plugins
- Flutter plugin
- Dart plugin
```

---

## Project Structure

```
local_vault/
├── android/                 # Android native code
│   ├── app/
│   │   ├── src/main/
│   │   │   ├── AndroidManifest.xml
│   │   │   └── kotlin/
│   │   └── build.gradle
│   └── build.gradle
├── windows/                 # Windows native code
│   ├── runner/
│   │   └── main.cpp
│   └── CMakeLists.txt
├── lib/                     # Dart source code
│   ├── app/                 # App initialization
│   ├── db/                  # Database (Isar)
│   ├── models/              # Data models
│   ├── services/            # Business logic
│   ├── ui/                  # UI screens
│   ├── utils/               # Utilities
│   ├── fvp_stub.dart        # FVP stub (Android)
│   ├── fvp_real.dart        # FVP implementation (Windows)
│   └── main.dart            # Entry point
├── App_Icon/                # App icons
├── build/                   # Build outputs (gitignored)
├── pubspec.yaml             # Dependencies
├── .gitignore               # Git ignore rules
├── README.md                # Project overview
├── DEVELOPMENT.md           # This file
├── GUIDE.md                 # User guide
└── CHANGELOG.md             # Version history
```

---

## Building

### Windows Build

#### Option 1: Using Build Script (Recommended)
```bash
# Run automated build script
build_windows.bat
```

#### Option 2: Manual Build
```bash
# Step 1: Ensure FVP is enabled in pubspec.yaml
# Uncomment these lines:
#   fvp:
#     version: ^0.28.0

# Step 2: Get dependencies
flutter pub get

# Step 3: Build Windows app
flutter build windows --release

# Step 4: Create installer
dart run inno_bundle:build --release
```

**Output**: `build\windows\x64\installer\Release\LocalVault-x86_64-[version]-Installer.exe`

---

### Android Build

#### Option 1: Using Build Script (Recommended)
```bash
# Run automated build script
build_android.bat
```

#### Option 2: Manual Build
```bash
# Step 1: Comment out FVP in pubspec.yaml
# Comment these lines:
#   # fvp:
#   #   version: ^0.28.0

# Step 2: Get dependencies
flutter pub get

# Step 3: Clean build cache (if needed)
flutter clean

# Step 4: Build APK
flutter build apk --release
```

**Output**: `build\app\outputs\flutter-apk\app-release.apk`

---

### Build Scripts Explained

**build_windows.bat:**
- Ensures FVP dependency is enabled
- Runs `flutter pub get`
- Builds Windows installer with Inno Setup
- Handles all dependencies automatically

**build_android.bat:**
- Comments out FVP dependency (Android incompatible)
- Runs `flutter pub get`
- Builds Android APK
- Restores FVP dependency for next Windows build

---

## Development Workflow

### Running in Debug Mode

**Windows:**
```bash
flutter run -d windows
```

**Android:**
```bash
# Connect device or start emulator
flutter devices

# Run on device
flutter run -d <device-id>
```

### Hot Reload
Press `r` in terminal during debug session to hot reload changes.

### Code Generation

When modifying Isar models:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Linting & Analysis

```bash
# Run analyzer
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

---

## Key Dependencies

### Core Dependencies
```yaml
flutter: sdk
isar: ^3.1.0+1                    # Database
isar_flutter_libs: ^3.1.0+1       # Isar native libs
encrypt: ^5.0.1                   # Encryption
flutter_secure_storage: ^8.0.0    # Secure key storage
file_picker: ^5.5.0               # File selection
archive: ^3.4.9                   # ZIP handling
video_player: ^2.8.1              # Video playback
```

### Windows-Only Dependencies
```yaml
fvp: ^0.28.0                      # Hardware-accelerated video
```

### Android-Only Dependencies
```yaml
uri_content: ^0.0.3               # SAF support
permission_handler: ^10.4.5       # Permissions
```

### Dev Dependencies
```yaml
build_runner: ^2.4.9              # Code generation
isar_generator: ^3.1.0+1          # Isar code gen
msix: ^3.10.0                     # Windows packaging
inno_bundle: ^0.4.1               # Inno Setup integration
```

---

---

## FVP (Flutter Video Player) Handling

### Why FVP Needs Special Handling

FVP is a Windows-only package for hardware-accelerated video playback. It causes Android builds to fail due to Windows-specific native dependencies.

### Solution: Conditional Imports

The app uses conditional imports to handle FVP:
- `lib/fvp_stub.dart` - No-op implementation for non-Windows platforms
- `lib/fvp_real.dart` - Real FVP implementation for Windows
- `lib/main.dart` - Conditionally imports based on platform

### Current State

- ✅ FVP is currently **commented out** in pubspec.yaml
- ✅ Ready for Android build
- ✅ Both `fvp_real.dart` and `fvp_stub.dart` are no-op functions
- ⚠️ For Windows builds: Need to re-implement FVP (uncomment in pubspec.yaml, update fvp_real.dart)

### Build Scripts Handle This Automatically

The build scripts (`build_windows.bat` and `build_android.bat`) automatically:
- Comment/uncomment FVP dependency as needed
- Run `flutter pub get`
- Build for the target platform
- Restore FVP dependency for next build

---

## Troubleshooting

### Common Issues

#### 1. FVP Build Errors on Android
**Problem**: `Error: Couldn't resolve the package 'fvp'`

**Solution**:
```bash
# Comment out FVP in pubspec.yaml
# Or use build_android.bat script
```

#### 2. Invalid Depfile Errors
**Problem**: `Invalid depfile: kernel_snapshot.d`

**Solution**:
```bash
flutter clean
flutter pub get
flutter build apk --release
```

#### 3. Isar Code Generation Fails
**Problem**: Models not generating

**Solution**:
```bash
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 4. Windows Build Fails
**Problem**: Missing Visual Studio components

**Solution**:
- Install Visual Studio 2022
- Install "Desktop development with C++" workload
- Install Windows 10 SDK

#### 5. Android Build Fails
**Problem**: Gradle errors

**Solution**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter build apk --release
```

#### 6. Inno Setup Not Found
**Problem**: `dart run inno_bundle:build` fails

**Solution**:
- Install Inno Setup 6 from https://jrsoftware.org/isdl.php
- Add to PATH or use default installation path

---

## Git Large File Handling

### Problem
Git fails to push due to large files (APKs, EXEs, build artifacts).

### Solution 1: Update .gitignore (Recommended)
```bash
# Already configured in .gitignore
# Excludes: build/, *.apk, *.exe, etc.
```

### Solution 2: Use Git LFS
```bash
# Install Git LFS
git lfs install

# Track large files
git lfs track "*.apk"
git lfs track "*.exe"

# Commit and push
git add .gitattributes
git commit -m "Add Git LFS tracking"
git push
```

### Solution 3: Remove Large Files from History
```bash
# If already committed large files
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch *.apk *.exe" \
  --prune-empty --tag-name-filter cat -- --all

# Force push
git push origin --force --all
```

---

## Version Management

### Updating Version

Edit `pubspec.yaml`:
```yaml
version: 2.5.2+6  # Format: MAJOR.MINOR.PATCH+BUILD
```

### Version Naming Convention
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes
- **BUILD**: Build number (increment for each build)

---

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing Checklist
- [ ] Import folder (small and large)
- [ ] Import ZIP (with and without password)
- [ ] Create/rename/delete folders
- [ ] Multi-select and batch move
- [ ] Search functionality
- [ ] Export to manga readers
- [ ] Password change
- [ ] App restart and vault unlock

---

## Contributing

### Code Style
- Follow Dart style guide
- Use `flutter format` before committing
- Run `flutter analyze` to check for issues

### Commit Messages
```
feat: Add multi-folder selection
fix: Resolve ZIP import crash
docs: Update README with new features
refactor: Optimize batch encryption
```

### Pull Request Process
1. Fork repository
2. Create feature branch
3. Make changes
4. Test thoroughly
5. Submit PR with description

---

## Release Process

### 1. Update Version
```yaml
# pubspec.yaml
version: 2.5.3+7
```

### 2. Update Changelog
```markdown
# CHANGELOG.md
## [2.5.3] - 2024-02-15
- Added feature X
- Fixed bug Y
```

### 3. Build Release
```bash
# Windows
build_windows.bat

# Android
build_android.bat
```

### 4. Test Release Builds
- Install on clean system
- Test all major features
- Verify no crashes

### 5. Create GitHub Release
```bash
git tag v2.5.3
git push origin v2.5.3
```

### 6. Upload Artifacts
- Upload Windows installer
- Upload Android APK
- Add release notes

---

## Resources

### Documentation
- [Flutter Docs](https://docs.flutter.dev)
- [Dart Docs](https://dart.dev/guides)
- [Isar Docs](https://isar.dev)

### Community
- [Flutter Discord](https://discord.gg/flutter)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

### Tools
- [Flutter DevTools](https://docs.flutter.dev/development/tools/devtools/overview)
- [Dart Analyzer](https://dart.dev/tools/dart-analyze)

---

**Happy Coding! 🚀**
