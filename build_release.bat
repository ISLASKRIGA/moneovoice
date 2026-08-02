@echo off
echo Actualizando local.properties con nueva version...
powershell -Command "(Get-Content 'android\local.properties') -replace 'flutter.versionName=.*', 'flutter.versionName=1.0.8' -replace 'flutter.versionCode=.*', 'flutter.versionCode=9' | Set-Content 'android\local.properties'"
echo Construyendo App Bundle v1.0.8+9...
call "C:\Users\chuch\flutter\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat" build appbundle --release
echo.
if %ERRORLEVEL%==0 (
    echo [OK] App Bundle generado en: build\app\outputs\bundle\release\app-release.aab
) else (
    echo [ERROR] El build fallo con codigo %ERRORLEVEL%
)
pause
