@echo off

if "%1" equ "" goto help

set ANDROID_NDK=C:\android\ndk
set ANDROID_SDK=C:\android\sdk
set JAVA_SDK=C:\Program Files\Java\jdk1.8.0_102

set APK=NativeExample.apk

for /f %%v in ('dir /b "%ANDROID_SDK%\build-tools"') do set BUILD_VER=%%v

if "%1" equ "go" goto :go
if "%1" equ "run" goto :run
if "%1" equ "build" goto :build
if "%1" equ "remove" goto :remove
if "%1" equ "install" goto :install
if "%1" equ "launch" goto :launch
if "%1" equ "log" goto :log

:help

echo Usage: %~nx0 command
echo.
echo Where command is:
echo   go        - builds, installs and runs .apk file
echo   run       - installs and runs .apk file
echo   build     - only builds .apk file
echo   remove    - removes installed .apk
echo   install   - only installs .apk file on connected device
echo   launch    - ony runs already installed .apk file
echo   log       - show logcat

goto :eof

:go
call :build
call :install
call :launch
goto :eof

:run
call :install
call :launch
goto :eof

:build

if not exist bin mkdir bin

call "%ANDROID_NDK%\ndk-build.cmd" -j4 NDK_LIBS_OUT=lib\lib
if ERRORLEVEL 1 exit /b 1

"%ANDROID_SDK%\build-tools\%BUILD_VER%\aapt.exe" package -f -M AndroidManifest.xml -I "%ANDROID_SDK%\platforms\android-24\android.jar" -A assets -F bin\%APK%.build lib
if ERRORLEVEL 1 exit /b 1

if not exist .keystore (
  "%JAVA_SDK%\bin\keytool.exe" -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
  if ERRORLEVEL 1 exit /b 1
)

"%JAVA_SDK%\bin\jarsigner.exe" -storepass android -keystore .keystore bin\%APK%.build androiddebugkey >nul
if ERRORLEVEL 1 exit /b 1

"%ANDROID_SDK%\build-tools\%BUILD_VER%\zipalign.exe" -f 4 bin\%APK%.build bin\%APK%
if ERRORLEVEL 1 exit /b 1

del /q bin\%APK%.build

goto :eof

:remove
call :get_package_activity
"%ANDROID_SDK%\platform-tools\adb.exe" uninstall %PACKAGE%
if ERRORLEVEL 1 exit /b 1
goto :eof

:install
"%ANDROID_SDK%\platform-tools\adb.exe" install -r bin\%APK%
if ERRORLEVEL 1 exit /b 1
goto :eof

:launch
call :get_package_activity
"%ANDROID_SDK%\platform-tools\adb.exe" shell am start -n %PACKAGE%/%ACTIVITY%
if ERRORLEVEL 1 exit /b 1
goto :eof

:log
"%ANDROID_SDK%\platform-tools\adb.exe" logcat -d NativeExample:V *:S
if ERRORLEVEL 1 exit /b 1
goto :eof

:get_package_activity
for /f "tokens=1-2" %%a in ('"%ANDROID_SDK%\build-tools\%BUILD_VER%\aapt.exe" dump badging bin\%APK%') do (
  if "%%a" equ "package:" (
    for /f "tokens=2 delims='" %%v in ("%%b") do (
      set PACKAGE=%%v
    )
  ) else if "%%a" equ "launchable-activity:" (
    for /f "tokens=2 delims='" %%v in ("%%b") do (
      set ACTIVITY=%%v
    )
  )
)
goto :eof
