#!/usr/bin/env bash
# Chạy toàn bộ LHT Money trên máy dev: SQL Server (Docker) → build app web → API .NET (phục vụ cả web) ở http://localhost:5000
#   ./run.sh          chạy đầy đủ (build lại web)
#   ./run.sh --no-web bỏ qua bước build Flutter web
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/flutter/bin:$PATH"

echo "▶ SQL Server (Docker)"
cd "$ROOT/server"
if [ ! -f .env ]; then
  printf 'MSSQL_SA_PASSWORD=Lht_%sA1!\n' "$(openssl rand -hex 8)" > .env && chmod 600 .env
  echo "  Đã tạo mật khẩu SA mới trong server/.env — nhớ cập nhật user-secrets ConnectionStrings:Default"
fi
docker compose up -d
until [ "$(docker inspect -f '{{.State.Health.Status}}' lht-sqlserver)" = "healthy" ]; do sleep 2; done

if [ "$1" != "--no-web" ]; then
  echo "▶ Build Flutter web"
  cd "$ROOT/app"
  flutter pub get >/dev/null
  flutter build web --release
  rm -rf "$ROOT/server/src/LHT.Api/wwwroot"
  cp -r build/web "$ROOT/server/src/LHT.Api/wwwroot"
fi

echo "▶ API .NET + SignalR (tự migrate DB + seed phân quyền) → http://localhost:5000"
cd "$ROOT/server"
dotnet run --project src/LHT.Api --launch-profile http
