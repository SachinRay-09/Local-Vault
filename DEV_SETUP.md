# Dev Setup — Local Vault (Windows PC)

Short checklist to get this repo building again for **Windows** and **Android**. Details and troubleshooting live in [`DEVELOPMENT.md`](DEVELOPMENT.md).

---

## 1. Install required software

| Tool | Why | Where |
|------|-----|--------|
| **Git** | Clone / version control | https://git-scm.com/downloads |
| **Flutter SDK** (stable, **3.16+** recommended; project SDK constraint is `^3.2.6`) | Build Dart/Flutter app | https://docs.flutter.dev/get-started/install/windows |
| **Android Studio** | Android SDK, emulator, platform tools | https://developer.android.com/studio |
| **Visual Studio 2022** (Community is fine) | Windows desktop C++ toolchain | https://visualstudio.microsoft.com/ — workload: **Desktop development with C++** + Windows 10/11 SDK |
| **JDK 17** (Android Studio usually bundles one) | Gradle / Android builds | Prefer Studio’s embedded JDK |
| **Inno Setup 6** (optional) | Windows `.exe` installer via `inno_bundle` | https://jrsoftware.org/isdl.php |

Add to `PATH`: Flutter `bin`, and ensure `flutter doctor` can see Android SDK + Visual Studio.

---

## 2. Android Studio extras

In **SDK Manager → SDK Platforms tab**, install all three:

- **Android 16 (API 36)** — matches the iQOO Z9x running OriginOS 6 (Android 16)
- **Android 14 (API 34)** — current `compileSdkVersion` / `targetSdkVersion` in `build.gradle`
- **Android 8.0 Oreo (API 26)** — `minSdkVersion`; build toolchain needs this locally

In **SDK Manager → SDK Tools tab**, install:

- Android SDK Build-Tools (latest)
- Android SDK Command-line Tools ← required for `flutter doctor --android-licenses`
- Android SDK Platform-Tools (`adb`)
- NDK (Side by side) version 26.x ← install now; needed in Phase 4 for native crypto bridge
- Google USB Driver ← Windows only; needed for the Z9x USB connection

Accept licenses: `flutter doctor --android-licenses`

In `android/app/build.gradle`, set `compileSdkVersion 36` and `targetSdkVersion 36` to match the device.

Create a device or use a physical phone (iQOO Z9x, API 36) with USB debugging enabled:
Settings → About phone → tap Build number 7× → Developer options → USB debugging.

---

## 3. One-time project setup

```powershell
cd P:\personalVault\local_vault
flutter doctor
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

`build_runner` regenerates Isar `*.g.dart` files after model changes.

---

## 4. Run / build

**Windows (debug):**
```powershell
flutter run -d windows
```

**Windows (release + installer scripts):**
```powershell
.\build_windows.bat
```
If FVP hardware video is needed, uncomment the `fvp` dependency in `pubspec.yaml` first (see `DEVELOPMENT.md`). Default tree may have FVP commented for cross-platform builds.

**Android (debug on device):**
```powershell
flutter devices
flutter run -d <device_id>
```

**Android (release APK):**
```powershell
.\build_android.bat
```
or:
```powershell
flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk` (and under `android\app\outputs\...` depending on script).

---

## 5. IDE

- **VS Code / Cursor:** Flutter + Dart extensions  
- **Android Studio:** Flutter + Dart plugins  

Open the repo root (folder that contains `pubspec.yaml`).

---

## 6. Sanity checks

```powershell
flutter doctor -v
flutter analyze
flutter test
```

You are ready when `flutter doctor` shows no blocking issues for **Windows** and **Android** toolchains, `pub get` succeeds, and a debug run unlocks the login/setup screen.
