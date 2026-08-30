@echo off
setlocal

rem Always build from the directory containing this script.
pushd "%~dp0" || (
  echo ERROR: Could not open the project directory.
  exit /b 1
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter was not found on PATH.
  echo Install Flutter and add its bin directory to PATH, then try again.
  popd
  exit /b 1
)

echo Fetching project dependencies...
call flutter pub get
if errorlevel 1 goto :failed

echo Building the Android release APK...
call flutter build apk --release
if errorlevel 1 goto :failed

echo.
echo Android build complete.
echo Output: %~dp0build\app\outputs\flutter-apk\app-release.apk
popd
exit /b 0

:failed
echo.
echo ERROR: Android build failed. Review the Flutter output above.
echo Run "flutter doctor" to check the Android SDK, Java, and licenses.
popd
exit /b 1
