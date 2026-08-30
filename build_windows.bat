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

echo Enabling Flutter Windows desktop support...
call flutter config --enable-windows-desktop
if errorlevel 1 goto :failed

echo Fetching project dependencies...
call flutter pub get
if errorlevel 1 goto :failed

echo Building the Windows release...
call flutter build windows --release
if errorlevel 1 goto :failed

copy /Y "%~dp0packaging\windows\register.ps1" "%~dp0build\windows\x64\runner\Release\register.ps1" >nul
if errorlevel 1 goto :failed

echo.
echo Build complete.
echo Output: %~dp0build\windows\x64\runner\Release
popd
exit /b 0

:failed
echo.
echo ERROR: Windows build failed. Review the Flutter output above.
echo Run "flutter doctor" to check for missing Visual Studio components.
popd
exit /b 1
