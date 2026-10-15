@echo off
echo Building Windows Installer...
echo.
echo Step 1: Ensuring FVP dependency is enabled...
powershell -Command "(Get-Content pubspec.yaml) -replace '^  # fvp:', '  fvp:' | Set-Content pubspec.yaml"
powershell -Command "(Get-Content pubspec.yaml) -replace '^    # version:', '    version:' | Set-Content pubspec.yaml"

echo Step 2: Running flutter pub get...
call flutter pub get

echo Step 3: Building Windows installer...
call dart run inno_bundle:build --release

echo.
echo ========================================
echo Windows Installer built successfully!
echo Location: build\windows\x64\installer\Release\
echo ========================================
pause
