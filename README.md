# LHT Money

App quản lý chi tiêu cá nhân **offline-first**: Flutter (iOS/Android/Web) + ASP.NET Core 10 + SignalR + SQL Server.
Kế hoạch chi tiết: [PLAN.md](PLAN.md).

## Chạy toàn bộ

```bash
./run.sh            # SQL Server (Docker) → build Flutter web → API ở http://localhost:5000 (phục vụ cả app web)
./run.sh --no-web   # bỏ qua build web
```

Mở http://localhost:5000 trên trình duyệt (nên bật chế độ điện thoại trong DevTools).

| Thành phần | Địa chỉ |
|---|---|
| App web + API | http://localhost:5000 |
| OpenAPI (Swagger JSON) | http://localhost:5000/openapi/v1.json |
| SignalR | `/hubs/chat`, `/hubs/notifications` |
| SQL Server | `localhost,1433` · user `sa` · mật khẩu trong `server/.env` · DB `LHT_Money` |

**Chạy trên điện thoại** (cần Android SDK hoặc Mac + Xcode):
```bash
cd app
flutter run --dart-define=API_URL=http://<IP-máy-dev>:5000
```
Hoặc đổi địa chỉ máy chủ trong app: *Cài đặt → Địa chỉ máy chủ*.

### Tài khoản có sẵn trong DB dev (do kiểm thử tạo ra)
| Tài khoản | Mật khẩu | Vai trò |
|---|---|---|
| `a3527` | `123456` | ADMIN (người đăng ký đầu tiên tự thành admin) |
| `b3527` | `123456` | KHACH (vai trò tạo thử khi test phân quyền động) |
| `duy_ui` | `123456` | USER |

Muốn dùng tài khoản của bạn làm admin: đăng nhập `a3527` → *Quản trị → Người dùng* → gán vai trò ADMIN, hoặc xoá DB (`dotnet ef database drop`) để bắt đầu lại.

## Cấu trúc

```
app/                    Flutter
  lib/core/             theme, định dạng tiền/ngày, widget dùng chung (Pressable, AnimatedAmount...)
  lib/data/             LocalStore (Hive, offline), SyncEngine, ApiClient, Realtime (SignalR), Session (quyền động), logic.dart
  lib/features/         các màn hình
  ios/LHTWidget/        widget màn hình chính iOS (xem docs/WIDGET_IOS.md)
  test/                 unit test: tiền điện, chu kỳ, lịch lặp
server/
  src/LHT.Domain        entity (tên C# tiếng Anh, [Description] tiếng Việt)
  src/LHT.Application   nghiệp vụ: Auth, Sync, Friend, Chat, Post, EventShare, Permission, File
  src/LHT.Infrastructure EF Core + SQL Server, tên bảng/cột tiếng Việt không dấu (DbNames.cs), lưu file
  src/LHT.Api           controllers, SignalR hubs, JWT, phân quyền động [HasPermission]
database/LHT_Money.sql  script tạo DB (chạy được trên SQL Server khác bằng SSMS)
```

## Cơ chế chính

- **Offline-first**: mọi thao tác ghi vào Hive trên máy → đánh dấu "chờ đồng bộ". `SyncEngine` upload ảnh (xong thì xoá bản local) → `POST /sync/push` → gửi bài viết/tin nhắn trong hàng đợi → `GET /sync/pull?since=`. Chạy khi mở app, có mạng lại, 1,5s sau khi sửa, mỗi 60s, và khi server báo `SyncHint` qua SignalR.
- **Phân quyền động** (theo mô hình NS_PhuSan): PhanHe → ChucNang; VaiTro ↔ ChucNang; NguoiDung ↔ VaiTro. API kiểm tra bằng `[HasPermission("MÃ")]`, app hiện menu theo `GET /me/permissions`. Admin sửa trong app, có hiệu lực ngay.
- **Dữ liệu chu kỳ kinh nguyệt** mặc định chỉ lưu trên máy; bật đồng bộ trong cấu hình chu kỳ.
- **Lịch trình theo giờ**: mỗi lịch trình có các hoạt động theo mốc giờ cho từng ngày (bảng `LichTrinhChiTiet`), người cùng tham gia cùng sửa được.
- **Danh mục cấu hình được** cho Chi, Thu, Lịch trình và Mẫu hoạt động (bảng `DanhMuc`, `Loai` = 1/2/3/4).
- **Thời gian cấu hình được** (Cài đặt → Thời gian & nhắc nhở, lưu ở `CaiDat.CauHinhThoiGianJson`): các mốc nhắc, nhắc mặc định, khung giờ timeline, bước làm tròn, thời lượng hoạt động mặc định, ngày đầu tuần. Không có hằng số thời gian cố định trong giao diện.
- **Nguồn tiền**: mỗi người chọn tài khoản mặc định hoặc "nhớ lần trước" (bảng `CaiDat`), lọc/thống kê theo Tiền mặt / Tài khoản.

## Kiểm thử đã chạy

- `flutter test`: 9/9 (tiền điện xuôi/ngược, chu kỳ + Ogino–Knaus, lịch lặp).
- API end-to-end bằng curl: đăng ký/đăng nhập/refresh, kết bạn, chat (gửi trùng id không bị nhân đôi), upload ảnh, bài viết + cảm xúc + bình luận + thông báo, sync (chặn sửa dữ liệu người khác), lịch trình chung (mời, chấp nhận, cùng sửa), phân quyền động.
- Giao diện web qua Chrome headless: thêm giao dịch offline → đăng ký → dữ liệu lên SQL Server; tắt server → thêm giao dịch → bật lại → tự đồng bộ; chat realtime 2 chiều; màn quản trị phân quyền.

## Chưa làm / cần môi trường khác

- **Build iOS** cần Mac + Xcode (+ Apple Developer để có push & widget). Máy hiện tại (Linux) chỉ chạy được bản web.
- **Push khi app tắt (FCM/APNs)**: server đang dùng `LoggingPushSender` (ghi log). Cần tạo Firebase project rồi thay bằng FcmPushSender.
- **Widget Android**: mới có widget iOS (Swift) + phần Dart ghi dữ liệu.
- Kế hoạch chung chia tiền, hũ chung, khoá Face ID, xuất Excel: Phase 6 trong PLAN.md.
