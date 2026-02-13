@echo off
REM Build Windows Installer using Inno Setup
REM This creates a single .exe installer file

echo ========================================
echo Building Local Vault Windows Installer
echo ========================================
echo.

echo Step 1: Cleaning previous builds...
call flutter clean
echo.

echo Step 2: Getting dependencies...
call flutter pub get
echo.

echo Step 3: Building release version...
call flutter build windows --release
echo.

echo Step 4: Creating Inno Setup installer...
call dart run inno_bundle:build --release
echo.

echo ========================================
echo Build Complete!
echo ========================================
echo.
echo Installer location:
echo build\windows\x64\installer\Release\
echo.
echo Look for: LocalVault_Setup.exe
echo.
pause
