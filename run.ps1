param(
    [switch]$NoWeb,
    [switch]$NoDocker
)

$ErrorActionPreference = "Stop"
$ROOT = $PSScriptRoot

# Máy không cài Docker → dùng SQL Server có sẵn trên máy (chuỗi kết nối trong appsettings.Development.json / user-secrets)
if (-not $NoDocker -and -not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "⚠ Không tìm thấy Docker → dùng SQL Server có sẵn trên máy." -ForegroundColor Yellow
    $NoDocker = $true
}

if (-not $NoDocker) {
    Write-Host "▶ SQL Server (Docker)" -ForegroundColor Cyan
    Set-Location "$ROOT/server"

    if (-not (Test-Path .env)) {
        $bytes = New-Object byte[] 8
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $hex = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
        $pass = "Lht_${hex}A1!"
        "MSSQL_SA_PASSWORD=$pass" | Out-File -FilePath .env -Encoding ascii
        Write-Host "  Đã tạo mật khẩu SA mới trong server/.env: $pass" -ForegroundColor Yellow
        Write-Host "  Nhớ cập nhật user-secrets ConnectionStrings:Default nếu chưa thiết lập!" -ForegroundColor Yellow
    }

    docker compose up -d

    Write-Host "  Đang đợi SQL Server khởi động..." -ForegroundColor Gray
    do {
        Start-Sleep -Seconds 2
        $status = docker inspect -f '{{.State.Health.Status}}' lht-sqlserver 2>$null
    } while ($status -ne "healthy")

    Write-Host "  SQL Server đã sẵn sàng!" -ForegroundColor Green
} else {
    Write-Host "▶ Bỏ qua Docker (sử dụng SQL Server có sẵn trên máy)" -ForegroundColor Yellow
}

$wwwroot = "$ROOT/server/src/LHT.Api/wwwroot"
if (-not $NoWeb -and -not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "⚠ Không tìm thấy Flutter trên máy này → bỏ qua bước build web." -ForegroundColor Yellow
    Write-Host "  Cài Flutter: https://docs.flutter.dev/get-started/install/windows rồi thêm thư mục flutter\bin vào PATH." -ForegroundColor Yellow
    if (-not (Test-Path "$wwwroot/index.html")) {
        Write-Host "  Chưa có bản web trong wwwroot: API vẫn chạy nhưng mở http://localhost:5000 sẽ chưa có giao diện." -ForegroundColor Yellow
    }
    $NoWeb = $true
}

if (-not $NoWeb) {
    Write-Host "▶ Build Flutter web" -ForegroundColor Cyan
    Set-Location "$ROOT/app"
    flutter pub get
    flutter build web --release

    if (Test-Path $wwwroot) {
        Remove-Item -Recurse -Force $wwwroot
    }
    Copy-Item -Recurse "build/web" $wwwroot
}

Write-Host "▶ API .NET + SignalR (tự migrate DB + seed phân quyền) -> http://localhost:5000" -ForegroundColor Cyan
Set-Location "$ROOT/server"
dotnet run --project src/LHT.Api --launch-profile http

