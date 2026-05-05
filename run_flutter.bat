@echo off
cd /d "%~dp0"
echo Current directory: %CD%
echo.
echo Running Flutter commands from: %CD%
echo.
flutter pub get
echo.
echo Dependencies installed! You can now run:
echo   flutter run -d chrome
pause


