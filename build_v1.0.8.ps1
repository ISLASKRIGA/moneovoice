Set-Location "C:\Users\chuch\AndroidStudioProjects\prueba"
$env:Path = "C:\Users\chuch\flutter\flutter_windows_3.27.1-stable\flutter\bin;" + $env:Path
Write-Host "Building iMoney v1.0.8+9 App Bundle..." -ForegroundColor Cyan
& flutter build appbundle --release
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] App Bundle listo en:" -ForegroundColor Green
    Write-Host "  build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Yellow
} else {
    Write-Host "`n[ERROR] Build fallido." -ForegroundColor Red
}
Read-Host "Presiona Enter para cerrar"
