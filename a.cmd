@echo off

set APK=NativeExample.apk

if "%ANDROID_NDK%" equ "" set ANDROID_NDK=C:\android\ndk
if "%ANDROID_SDK%" equ "" set ANDROID_SDK=C:\android\sdk
if "%JAVA_JDK%" equ "" set JAVA_JDK=C:\Program Files\Java\jdk1.8.0_102

call :check || exit /b 1

if "%1" equ "run" goto :run
if "%1" equ "build" goto :build
if "%1" equ "remove" goto :remove
if "%1" equ "install" goto :install
if "%1" equ "launch" goto :launch
if "%1" equ "log" goto :log
if "%1" equ "" goto :go

echo Usage: %~nx0 [command]
echo By default build, install and run .apk file.
echo.
echo Optional [command] can be:
echo   run       - only install and run .apk file
echo   build     - only build .apk file
echo   remove    - remove installed .apk
echo   install   - only install .apk file on connected device
echo   launch    - ony run already installed .apk file
echo   log       - show logcat

goto :eof

:go
call :build || exit /b 1
call :install || exit /b 1
call :launch || exit /b 1
goto :eof

:run
call :install || exit /b 1
call :launch || exit /b 1
goto :eof

:build

if not exist bin mkdir bin

call "%ANDROID_NDK%\ndk-build.cmd" -j4 NDK_LIBS_OUT=lib\lib || exit /b 1

"%ANDROID_SDK%\build-tools\%BUILD_TOOLS%\aapt.exe" package -f -M AndroidManifest.xml -I "%ANDROID_SDK%\platforms\%PLATFORM%\android.jar" -A assets -F bin\%APK%.build lib
if ERRORLEVEL 1 exit /b 1

if not exist .keystore (
  "%JAVA_JDK%\bin\keytool.exe" -genkey -dname "CN=Android Debug, O=Android, C=US" -keystore .keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 30000
  if ERRORLEVEL 1 exit /b 1
)

"%JAVA_JDK%\bin\jarsigner.exe" -storepass android -keystore .keystore bin\%APK%.build androiddebugkey >nul
if ERRORLEVEL 1 exit /b 1

"%ANDROID_SDK%\build-tools\%BUILD_TOOLS%\zipalign.exe" -f 4 bin\%APK%.build bin\%APK%
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
for /f "tokens=1-2" %%a in ('"%ANDROID_SDK%\build-tools\%BUILD_TOOLS%\aapt.exe" dump badging bin\%APK%') do (
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

:check
if not exist "%ANDROID_NDK%\ndk-build.cmd" (
  echo Android NDK not found in "%ANDROID_NDK%"
  exit /b 1
)
if not exist "%ANDROID_SDK%" (
  echo Android SDK not found in "%ANDROID_SDK%"
  exit /b 1
)
if not exist "%JAVA_JDK%\bin\javac.exe" (
  echo Java JDK not found in "%JAVA_JDK%"
  exit /b 1
)
if not exist "%ANDROID_SDK%\platform-tools\adb.exe" (
  echo Please install Android SDK Platform-tools
  exit /b 1
)
for /f %%v in ('dir /O-D /b "%ANDROID_SDK%\build-tools"') do (
  set BUILD_TOOLS=%%v
  goto :tools_ok
)
:tools_ok
if not exist "%ANDROID_SDK%\build-tools\%BUILD_TOOLS%\aapt.exe" (
  echo Please install Android SDK Build-tools
  exit /b 1
)
for /f %%v in ('dir /O-D /b "%ANDROID_SDK%\platforms"') do (
  set PLATFORM=%%v
  goto :platform_ok
)
:platform_ok
if not exist "%ANDROID_SDK%\platforms\%PLATFORM%\android.jar" (
  echo Please install at least one Android SDK platform
  exit /b 1
)

goto :eof
