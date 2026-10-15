@echo off
echo Building Android APK...
echo.
echo Step 1: Commenting out FVP dependency...
powershell -Command "(Get-Content pubspec.yaml) -replace '^  fvp:', '  # fvp:' | Set-Content pubspec.yaml"
powershell -Command "(Get-Content pubspec.yaml) -replace '^    version:', '    # version:' | Set-Content pubspec.yaml"

echo Step 2: Running flutter pub get...
call flutter pub get

echo Step 3: Building Android APK...
call flutter build apk --release

echo Step 4: Restoring FVP dependency...
powershell -Command "(Get-Content pubspec.yaml) -replace '^  # fvp:', '  fvp:' | Set-Content pubspec.yaml"
powershell -Command "(Get-Content pubspec.yaml) -replace '^    # version:', '    version:' | Set-Content pubspec.yaml"

echo.
echo ========================================
echo Android APK built successfully!
echo Location: build\app\outputs\flutter-apk\app-release.apk
echo ========================================
pause
