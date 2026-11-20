# Kế hoạch app Quản lý Chi tiêu (tên tạm: **LHT Money**)

> File chuẩn bị trước khi bắt đầu code. Ghi lại phạm vi, kiến trúc, mô hình dữ liệu và lộ trình.
> Giao diện tham khảo: https://github.com/tai0112/ExpenseManager (app cũ của bạn) — **cần mở lại repo để chốt màu sắc, bố cục màn hình chính, form thêm giao dịch** trước khi làm Phase 1 (mục 11).

---

## 1. Mục tiêu

App điện thoại cá nhân (**ưu tiên iOS**, Android dùng chung code) để:
- Ghi chép **thu và chi** trên **nhiều tài khoản/ví**, nhiều loại tiền tệ; thống kê theo tháng, danh mục, tổng.
- Tiện ích: tính tiền điện bậc thang, đếm ngày yêu, theo dõi kinh nguyệt, định mức + cảnh báo, hũ tiết kiệm, lịch trình/timeline có ảnh.
- Mạng xã hội nhỏ: kết bạn, nhắn tin, **đăng bài**, chia sẻ & lên lịch trình cùng nhau — realtime bằng **SignalR**.
- **Offline-first**: không có mạng vẫn dùng đầy đủ, có mạng thì tự đồng bộ rồi dọn cache.
- Thông báo đẩy, widget màn hình chính, animation mượt.
- Giai đoạn đầu **chạy hoàn toàn local**: API .NET chạy trên máy dev, SQL Server tạm chạy trong Docker, chưa thuê cloud.

---

## 2. Công nghệ

### 2.1 App (Flutter)
| Lớp | Lựa chọn | Ghi chú |
|---|---|---|
| App | **Flutter 3.x (Dart)** | iOS trước, Android sau |
| State | **Riverpod** | |
| Điều hướng | **go_router** | Deep link từ notification/widget |
| DB local | **Hive CE** (chạy cả iOS, Android, Web) — lưu JSON từng bản ghi + cờ chờ đồng bộ | Thống kê tính trên máy, chạy offline |
| HTTP | **dio** (interceptor JWT, refresh token, retry) | |
| Realtime | **signalr_netcore** | Kết nối tới các Hub của .NET |
| Push | **Firebase Cloud Messaging → APNs** + `flutter_local_notifications` | FCM cho tin nhắn/bài viết/lời mời; local cho nhắc lịch, định mức, kinh nguyệt |
| Widget | **home_widget** + iOS WidgetKit extension (Swift) | Widget iOS bắt buộc viết phần UI bằng SwiftUI |
| Ảnh | `image_picker`, `camera`, `flutter_image_compress`, `photo_view`, `cached_network_image` | |
| Biểu đồ / Lịch | `fl_chart`, `table_calendar` | |
| Animation | `animations` (`OpenContainer`, `SharedAxisTransition`), `flutter_animate`, `Hero`, `lottie` | |
| Mạng / nền | `connectivity_plus`, `workmanager` (Android) + Background Fetch (iOS) | iOS giới hạn chạy nền → sync chủ yếu khi mở app / có mạng trở lại |

> ⚠️ **Build iOS cần macOS + Xcode.** Máy hiện tại là Linux: code và test trên Android emulator / iOS qua Mac thật, hoặc dùng CI build iOS (Codemagic / GitHub Actions macOS runner). Cần tài khoản Apple Developer (99$/năm) để có APNs, widget và cài lên máy thật lâu dài.

### 2.2 Backend (.NET)
| Lớp | Lựa chọn |
|---|---|
| Framework | **ASP.NET Core (.NET 10 LTS)** — Web API + **SignalR** |
| DB | **SQL Server 2022** + **EF Core 10** (code-first, migrations) |
| Auth | JWT access token + refresh token (ASP.NET Identity hoặc tự viết bảng Users) |
| Validation / Mapping | FluentValidation, Mapster |
| Lưu file | `IFileStorage` → giai đoạn đầu lưu ổ đĩa local (`/uploads`), sau đổi sang MinIO/S3 không sửa code nghiệp vụ |
| Push | FirebaseAdmin SDK (gửi FCM → APNs) |
| Log / Docs | Serilog, Swagger (OpenAPI) |
| Job nền | Hosted Service (hoặc Hangfire) — dọn file mồ côi, gửi nhắc lịch chung |
| Chạy local | SQL Server trong Docker (`server/docker-compose.yml`), API chạy bằng `dotnet run` |

---

## 3. Danh sách tính năng

### 3.1 Giao dịch, Tài khoản, Tiền tệ
- **Loại giao dịch**: Chi, **Thu**, **Chuyển khoản** giữa 2 tài khoản (không tính vào thu/chi).
- Trường: số tiền, tài khoản, danh mục, ngày giờ, ghi chú, **nhiều ảnh**, gắn với lịch trình/hũ (tuỳ chọn).
- **Nhiều tài khoản/ví**: Tiền mặt, Ngân hàng, Ví điện tử, Thẻ tín dụng… mỗi tài khoản có tên, icon, màu, **số dư đầu**, **tiền tệ riêng**, cờ "tính vào tổng". Số dư = số dư đầu + thu − chi ± chuyển khoản.
- **Cấu hình tiền tệ**: chọn **tiền tệ chính** (mặc định VND), thêm tiền tệ khác (USD, JPY…), mỗi loại có ký hiệu, số chữ số thập phân, vị trí ký hiệu, dấu phân cách. **Tỷ giá nhập tay** (lưu lịch sử theo ngày) để quy đổi khi thống kê tổng — chạy offline, không phụ thuộc API tỷ giá.
- Danh mục **2 cấp** riêng cho Thu và Chi, thêm/sửa/xoá/sắp xếp thoải mái; chọn icon + màu.
- Bộ mặc định — Chi: Ăn uống, Đi lại, Nhà cửa (Điện, Nước, Internet), Mua sắm, Giải trí, Hẹn hò, Sức khoẻ… · Thu: Lương, Thưởng, Bán đồ, Được tặng, Khác.
- Giao dịch định kỳ (tiền nhà, lương…) tự tạo theo lịch.
- Tìm kiếm, lọc theo khoảng ngày / tài khoản / danh mục / số tiền / loại.
- Xem **Danh sách** (nhóm theo ngày, tổng thu/chi mỗi ngày) và **Lịch** (mỗi ô hiện tổng thu/chi).

### 3.2 Thống kê
- Theo **tháng**: tổng thu, tổng chi, **chênh lệch (tiết kiệm được)**, so với tháng trước.
- Theo **danh mục cha / con** (biểu đồ tròn, chạm để drill-down), tách riêng Thu và Chi.
- Theo **tài khoản**, theo **năm** (cột 12 tháng thu vs chi), khoảng thời gian bất kỳ.
- Xu hướng theo ngày (đường), tổng tài sản theo thời gian.
- Mọi số liệu quy đổi về tiền tệ chính theo tỷ giá đã cấu hình. Tính trên DB local → xem được offline.

### 3.3 Tính tiền điện bậc thang (cấu hình động)
- Người dùng tạo **bảng giá** gồm N bậc tuỳ ý. Mỗi bậc: `từ kWh`, `đến kWh` (bậc cuối để trống = không giới hạn), `đơn giá`.
- Thêm thuế VAT (% cấu hình), phí cố định (nếu có).
- 2 chế độ nhập:
  1. Nhập **chỉ số cũ / chỉ số mới** (hoặc số kWh) → ra số tiền, hiện bảng chi tiết từng bậc.
  2. Nhập **số tiền** → tính ngược ra số kWh tương ứng.
- Lưu lịch sử từng tháng; nút "Lưu thành giao dịch" vào danh mục Điện (kèm ảnh hoá đơn / đồng hồ).
- Preset mặc định (giá sinh hoạt EVN — **cần đối chiếu lại giá hiện hành**, người dùng tự sửa):

| Bậc | kWh | Đơn giá (đ/kWh) |
|---|---|---|
| 1 | 0–50 | 1.984 |
| 2 | 51–100 | 2.050 |
| 3 | 101–200 | 2.380 |
| 4 | 201–300 | 2.998 |
| 5 | 301–400 | 3.350 |
| 6 | 401+ | 3.460 |

Thuật toán:
```
remaining = kwh; total = 0
for tier in tiers (sắp xếp theo from):
    cap = tier.to == null ? remaining : (tier.to - tier.from + 1)
    used = min(remaining, cap)
    total += used * tier.price; remaining -= used
    if remaining <= 0: break
total = total * (1 + vat) + fixedFee
```
Tính ngược (tiền → kWh): bỏ phí cố định và VAT, rồi đi qua từng bậc trừ dần số tiền cho đến khi hết.

### 3.4 Đếm ngày yêu
- Cấu hình: ngày bắt đầu, tên, ảnh 2 người.
- Hiển thị: số ngày, dạng năm/tháng/ngày, đếm ngược tới mốc kế tiếp (100, 365, 500, 1000 ngày, kỷ niệm năm), sinh nhật người ấy.
- Nhắc trước mốc X ngày (cấu hình). Có widget riêng.

### 3.5 Định mức chi tiêu & Cảnh báo
- Định mức theo: **tổng tháng**, **từng danh mục**, **từng tài khoản**, hoặc theo tuần/ngày.
- Ngưỡng cảnh báo cấu hình (mặc định **80%** "sắp vượt" và **100%** "đã vượt").
- Kiểm tra ngay khi thêm giao dịch (kể cả offline) → local notification + banner + thanh tiến độ đổi màu (xanh → vàng → đỏ).
- Gợi ý "mỗi ngày còn được tiêu bao nhiêu" cho phần còn lại của tháng.

### 3.6 Hũ tiết kiệm
- Nhiều hũ: tên, icon, mục tiêu (số tiền + hạn), ảnh, tiền tệ.
- Nạp / rút tiền **từ một tài khoản** (ghi thành giao dịch chuyển khoản), lịch sử, % tiến độ với animation đổ đầy hũ.
- Nạp tự động định kỳ (nhắc), hũ chung với bạn bè (Phase 6).

### 3.7 Lịch trình / Timeline
- Sự kiện: tiêu đề, giờ bắt đầu–kết thúc, địa điểm, ghi chú, loại (đi chơi / công việc / khác), màu.
- **Ảnh cho từng lịch trình**: ảnh bìa + album ảnh (chụp/chọn nhiều ảnh, thêm trước hoặc sau sự kiện). Với lịch chung, mọi người tham gia đều thêm ảnh được. Xem album dạng lưới, vuốt full màn hình.
- **Lặp lại**: không lặp, hằng ngày, hằng tuần (chọn thứ), hằng tháng (cố định 1 ngày), hằng năm. Mỗi lần lặp có thể có album ảnh riêng.
- Xem theo **timeline trong ngày** (dòng thời gian dọc, hiện thumbnail ảnh) và **lịch tháng**.
- Nhắc trước N phút (cấu hình).
- Liên kết chi phí dự kiến/thực tế với giao dịch → tổng chi của chuyến đi.
- Nút "Đăng bài từ lịch trình này" (xem 3.10).

### 3.8 Menu cấu hình được
- Bật/tắt và **kéo thả sắp xếp**: thanh điều hướng dưới (tối đa 5) + lưới tiện ích ở trang chủ.
- Khác: theme sáng/tối, màu chủ đạo, tiền tệ chính, ngày bắt đầu tháng tài chính (vd ngày nhận lương), khoá app bằng Face ID / PIN.

### 3.9 Bạn bè, Nhắn tin, Lịch chung
- Tài khoản (email + mật khẩu; Sign in with Apple ở bản sau — bắt buộc nếu thêm đăng nhập mạng xã hội khác trên iOS). Tìm bạn bằng username / mã QR.
- Lời mời kết bạn: gửi / chấp nhận / từ chối / huỷ kết bạn / chặn.
- Chat 1-1 và nhóm: text, ảnh, trạng thái đã gửi / đã nhận / đã xem, **đang nhập…**, **online/offline** — tất cả qua SignalR. Gửi lúc offline nằm trong hàng đợi.
- **Chia sẻ lịch trình**: mời bạn vào sự kiện, xác nhận tham gia, cùng sửa, cùng thêm ảnh; thay đổi đẩy realtime.
- **Lên lịch cùng nhau**: kế hoạch chung (vd chuyến du lịch) gồm nhiều sự kiện, chia tiền chi phí (Phase 6).

### 3.10 Đăng bài (Feed)
- Bài viết: nội dung text, **nhiều ảnh**, cảm xúc/địa điểm, gắn **lịch trình** (hiện thẻ sự kiện + album) hoặc **hũ tiết kiệm** (khoe tiến độ).
- **Quyền xem**: Công khai với bạn bè / Chỉ mình tôi / Chọn người cụ thể.
- Tương tác: thả cảm xúc (like, tim, haha…), bình luận (trả lời 1 cấp), tag bạn bè.
- Feed bạn bè sắp theo thời gian, phân trang cursor; trang cá nhân hiện bài của mình.
- Bài mới / bình luận / cảm xúc đẩy realtime qua SignalR + push khi app tắt.
- Soạn bài lúc offline → lưu nháp, tự đăng khi có mạng.
- Sửa, xoá bài; báo cáo / ẩn bài (đơn giản).

### 3.11 Theo dõi kinh nguyệt
Có thể dùng để theo dõi cho bản thân hoặc cho bạn gái (gắn với mục Đếm ngày yêu).

**Số liệu tham khảo (đã đọc từ nguồn, ngày 20/11/2026):**

| Chỉ số | Giá trị | Nguồn |
|---|---|---|
| Độ dài chu kỳ bình thường (người trưởng thành) | 21–35 ngày, trung bình ~28 (womenshealth.gov ghi 24–38) | NHS, Cleveland Clinic, womenshealth.gov |
| Số ngày hành kinh | 2–7 ngày | NHS |
| Rụng trứng | khoảng **10–16 ngày trước** kỳ kinh tiếp theo (pha hoàng thể 12–16 ngày) | NHS, Wikipedia |
| Tuổi dậy thì | có thể mất tới 3 năm để chu kỳ ổn định; chu kỳ >38 ngày thường gặp | Cleveland Clinic, womenshealth.gov |
| Tinh trùng sống | tới 7 ngày trong ống dẫn trứng | NHS |
| Chu kỳ không đều | < 21 hoặc > 35 ngày | Cleveland Clinic |
| Nên đi khám | mất kinh ≥ 90 ngày (không mang thai/cho con bú); chu kỳ < 24 hoặc > 38 ngày; chưa có kinh ở tuổi 15–16 | womenshealth.gov, Cleveland Clinic |

Nguồn: nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle · my.clevelandclinic.org/health/articles/10132-menstrual-cycle · womenshealth.gov/menstrual-cycle/your-menstrual-cycle · en.wikipedia.org/wiki/Calendar-based_contraceptive_methods
(ACOG, Mayo Clinic, NCBI chặn truy cập tự động nên chưa đối chiếu được.)

**Công thức dự đoán** (các hằng số đều cấu hình được):
```
cycles      = độ dài 3–6 chu kỳ gần nhất (ngày bắt đầu kỳ sau − ngày bắt đầu kỳ trước)
              bỏ giá trị bất thường (< 15 hoặc > 90 ngày) khỏi phép tính trung bình
avgCycle    = trung bình(cycles)              // chưa có dữ liệu → mặc định 28
avgPeriod   = trung bình số ngày hành kinh     // mặc định 5
luteal      = 14                               // cấu hình 10–16

nextPeriod      = lastStart + avgCycle
nextPeriodRange = [lastStart + min(cycles), lastStart + max(cycles)]   // hiển thị "có thể từ … đến …"
ovulation       = nextPeriod − luteal
fertileWindow   = [ovulation − 5, ovulation + 1]    // tuỳ chỉnh được số ngày trước/sau
```

Phương pháp phụ (khi đủ dữ liệu):
- **Lịch (Ogino–Knaus)**, cần ≥ 6 chu kỳ: ngày dễ thụ thai đầu tiên = `chu kỳ ngắn nhất − 18`, ngày cuối = `chu kỳ dài nhất − 11` (tính từ ngày 1 của chu kỳ). Ví dụ chu kỳ 30–36 ngày → dễ thụ thai từ ngày 12 đến ngày 25.
- **Standard Days Method**: chỉ áp dụng nếu mọi chu kỳ nằm trong 26–32 ngày → ngày 8–19 là giai đoạn dễ thụ thai.

**Tính năng:**
- Ghi ngày bắt đầu/kết thúc, lượng máu (ít/vừa/nhiều), triệu chứng (đau bụng, mụn, tâm trạng…), ghi chú.
- Lịch màu: ngày hành kinh (đỏ), dự đoán (đỏ nhạt), cửa sổ thụ thai (xanh), ngày rụng trứng (đậm). Tự cập nhật dự đoán mỗi khi nhập kỳ mới.
- Thống kê: độ dài chu kỳ qua các tháng, độ dao động.
- Thông báo (local): trước kỳ kinh N ngày, bắt đầu cửa sổ thụ thai, trễ kinh X ngày; cảnh báo khi chu kỳ ngoài 21–35 ngày hoặc mất kinh ≥ 90 ngày → gợi ý đi khám.
- **Quyền riêng tư**: mặc định chỉ lưu trong máy (mã hoá), đồng bộ lên server và chia sẻ cho người yêu chỉ khi người dùng bật; có thể khoá riêng bằng Face ID / PIN.
- Hiện cảnh báo rõ: *dự đoán chỉ mang tính tham khảo, không dùng để tránh thai* (phương pháp lịch có tỷ lệ thất bại ~25%/năm khi dùng thông thường, theo Wikipedia).

### 3.12 Thông báo & Widget
| Loại | Nguồn |
|---|---|
| Nhắc lịch trình | Local (lên lịch sẵn, chạy offline) |
| Cảnh báo định mức | Local |
| Mốc ngày yêu, sinh nhật | Local |
| Sắp tới kỳ kinh, cửa sổ thụ thai, trễ kinh | Local |
| Nhắc ghi chi tiêu hằng tối, giao dịch định kỳ | Local |
| Tin nhắn, lời mời, lịch chung, bài viết / bình luận / cảm xúc | SignalR khi app đang mở · FCM→APNs khi app tắt |

> iOS chỉ cho tối đa **64 local notification** đang chờ → app lên lịch lại các nhắc nhở gần nhất mỗi lần mở app.

Widget (iOS WidgetKit, Android AppWidget): (1) Thu/chi tháng + % định mức, (2) Đếm ngày yêu, (3) Lịch trình hôm nay, (4) Kỳ kinh tiếp theo, (5) Nút thêm nhanh giao dịch (deep link).

### 3.13 Animation & cảm giác bấm
- Chuyển trang: `SharedAxisTransition` giữa các tab, `OpenContainer` từ nút "+" mở form.
- `Hero` cho ảnh, avatar, icon danh mục.
- Mọi nút có hiệu ứng nhấn (scale 0.96) và **haptic feedback** nhẹ (rất hợp iOS).
- Số tiền chạy (count-up), biểu đồ vẽ dần, danh sách xuất hiện so le, nút like nảy.
- Swipe để xoá/sửa, kéo xuống để làm mới/sync; cử chỉ vuốt-quay-lại chuẩn iOS (Cupertino page transition).
- Không giật lag: `const` widget, phân trang, thumbnail, nén ảnh.

---

## 4. Kiến trúc tổng thể

```
┌──────────── Flutter app ────────────┐
│ UI + animation                      │
│   │ Riverpod                        │
│ Use cases (domain)                  │
│   │                                 │
│ Repository ──► Drift/SQLite  ◄── UI luôn đọc từ đây
│   │               ▲                 │
│ Sync Engine ──────┘ (outbox, upload queue)
│ SignalR client ──── realtime        │
└───────│──────────────│──────────────┘
        │ REST (dio)   │ WebSocket
┌───────▼──────────────▼──────────────┐
│ ASP.NET Core API  +  SignalR Hubs   │
│ Application services                │
│ EF Core ──► SQL Server              │
│ IFileStorage ──► ổ đĩa local (/uploads) → MinIO/S3 sau
│ FirebaseAdmin ──► FCM ──► APNs      │
└─────────────────────────────────────┘
```

### 4.1 Cấu trúc thư mục repo
```
LHT/
  app/                        # Flutter
    lib/
      core/     (theme, router, animation, network/dio, signalr, utils tiền tệ/ngày)
      data/
        local/  (drift tables, dao)
        remote/ (api clients, dto)
        sync/   (outbox, sync engine, upload queue)
      features/
        transactions/ accounts/ currencies/ categories/ statistics/
        electricity/ love_counter/ cycle/ budgets/ savings_jars/
        schedule/ posts/ social/ (friends, chat, shared_plans)
        settings/ home_widgets/
      main.dart
    ios/  (Runner + WidgetExtension)
    android/
  server/                     # .NET
    src/
      LHT.Domain/
      LHT.Application/
      LHT.Infrastructure/
      LHT.Api/
    tests/
      LHT.UnitTests/
      LHT.IntegrationTests/
    docker-compose.yml
  docs/
  PLAN.md
```

---

## 5. Backend .NET — bộ khung (base)

Clean Architecture 4 project:

**LHT.Domain**
- `BaseEntity` (`Id: Guid` — client sinh UUID v7, `CreatedAt`, `UpdatedAt`, `DeletedAt`), `OwnedEntity : BaseEntity` (`UserId`).
- `ISoftDelete`, `IAuditable`, enum dùng chung, entity của từng module.

**LHT.Application**
- `IRepository<T>`, `IUnitOfWork`, `ICurrentUser`, `IFileStorage`, `IPushSender`, `IRealtimeNotifier`, `IDateTime`.
- `BaseService<TEntity, TDto, TCreate, TUpdate>`: CRUD chung có kiểm tra quyền sở hữu.
- Kết quả chuẩn: `Result<T>` / `ApiResponse<T> { success, data, error: { code, message, details } }`, `PagedResult<T>` (offset) và `CursorPage<T>` (feed, chat).
- FluentValidation cho mọi request, Mapster cho mapping, mã lỗi tập trung (`ErrorCodes`).
- Service đồng bộ: `SyncService` (push batch / pull theo `updatedSince`).

**LHT.Infrastructure**
- `AppDbContext` (EF Core + SQL Server), cấu hình Fluent API từng entity, migrations.
- **Global query filter** soft delete + `SaveChangesInterceptor` tự set `CreatedAt/UpdatedAt/DeletedAt`.
- `Repository<T>`, `UnitOfWork`, `LocalFileStorage` (lưu file + tạo thumbnail bằng ImageSharp), `FcmPushSender`, `JwtTokenService`, `PasswordHasher`.

**LHT.Api**
- `Program.cs`: DI theo module (`AddApplication()`, `AddInfrastructure()`), Swagger + JWT, CORS, rate limiting, API versioning (`/api/v1`), health check, Serilog.
- `BaseApiController` (trả `ApiResponse`, lấy `CurrentUserId`), **middleware xử lý exception toàn cục** → ProblemDetails/ApiResponse.
- Controllers: `Auth`, `Users`, `Accounts`, `Currencies`, `Categories`, `Transactions`, `Budgets`, `Jars`, `Electricity`, `Events`, `Plans`, `Cycle`, `Friends`, `Conversations`, `Messages`, `Posts`, `Comments`, `Reactions`, `Files`, `Sync`, `Devices` (đăng ký FCM token).
- **SignalR Hubs** (xác thực JWT qua `access_token` query):
  | Hub | Sự kiện |
  |---|---|
  | `ChatHub` | `SendMessage`, `MessageReceived`, `Typing`, `MessageDelivered`, `MessageRead` |
  | `PresenceHub` | online/offline, last seen (đếm kết nối theo user) |
  | `NotificationHub` | lời mời kết bạn, lịch chung thay đổi, bài viết mới, bình luận, cảm xúc |
  - Group theo `user:{id}`, `conversation:{id}`, `plan:{id}`.
  - `IRealtimeNotifier` bọc `IHubContext` để service gọi mà không phụ thuộc SignalR; user không online → fallback push FCM.
  - Sau này scale nhiều instance: thêm Redis backplane.

**Quy ước đặt tên:** tên bảng/cột/class bằng tiếng Anh (chuẩn C#/SQL, không lỗi dấu); **mô tả tiếng Việt** gắn bằng `[Description]` trên entity → tự ghi vào `MS_Description` của SQL Server (xem trong SSMS: Properties của bảng/cột). Comment code, thông báo lỗi trả về app: tiếng Việt.

**Chạy local:** `cd server && docker compose up -d` (SQL Server, mật khẩu SA trong `server/.env`) → `dotnet ef database update -p src/LHT.Infrastructure -s src/LHT.Api` → `dotnet run --project src/LHT.Api` ở `http://localhost:5000`. Connection string và JWT key lưu bằng `dotnet user-secrets`, không nằm trong code. Script SQL tạo DB: `database/LHT_Money.sql` (chạy được trên SQL Server khác bằng SSMS). App trên simulator/điện thoại trỏ vào IP máy dev (iOS cần cấu hình App Transport Security cho HTTP local, hoặc dùng HTTPS dev cert / ngrok).

---

## 6. Offline-first & Đồng bộ

Nguyên tắc: **mọi thao tác ghi vào DB local trước**, UI phản hồi ngay; Sync Engine lo việc đẩy lên server.

1. **ID sinh ở máy** (UUID v7) → không cần chờ server cấp ID.
2. Mỗi bản ghi có `updated_at`, `deleted_at` (xoá mềm), `sync_status` (`pending` / `synced`).
3. Mỗi thao tác tạo/sửa/xoá → 1 dòng trong **`outbox`** (`entity`, `entity_id`, `op`, `payload`, `created_at`, `retry_count`).
4. Ảnh (giao dịch, lịch trình, bài viết, tin nhắn): lưu file nén vào thư mục app + 1 dòng trong **`upload_queue`**.
5. Khi có mạng (connectivity + gọi `/health`), khi mở app, hoặc background fetch:
   - Upload ảnh (`POST /api/v1/files`, multipart) → nhận `fileId/url` → cập nhật bản ghi.
   - `POST /api/v1/sync/push` gửi batch outbox (gộp nhiều thao tác cùng bản ghi), server upsert idempotent theo `Id`.
   - Thành công → **xoá dòng outbox**, đánh dấu `synced`, **xoá file ảnh gốc tạm** (giữ thumbnail để xem offline).
   - Thất bại → tăng `retry_count`, backoff luỹ thừa.
   - `GET /api/v1/sync/pull?since=…` lấy thay đổi từ server, lưu `last_pulled_at`.
6. **Xung đột**: Last-Write-Wins theo `updated_at` cho dữ liệu cá nhân; lịch chung/bài viết ghi log chỉnh sửa và báo người liên quan.
7. Chat & bài viết offline: hiện trạng thái "đang chờ gửi", khi có mạng gửi qua REST rồi nhận xác nhận qua SignalR. Khi SignalR mất kết nối → tự reconnect và pull tin nhắn bị lỡ theo cursor.
8. Cache ảnh tải về: LRU giới hạn dung lượng (vd 200MB, cấu hình được).
9. Chế độ **chỉ dùng local** (không đăng nhập): mọi tính năng cá nhân chạy đầy đủ, outbox giữ lại; khi đăng nhập lần đầu sẽ đẩy toàn bộ lên.

---

## 7. Mô hình dữ liệu (bản nháp)

Tất cả bảng có: `id (uuid)`, `user_id` (nếu thuộc 1 người), `created_at`, `updated_at`, `deleted_at`.

| Bảng | Trường chính |
|---|---|
| `currencies` | code (VND, USD…), symbol, decimals, symbol_position, is_base |
| `exchange_rates` | from_code, to_code, rate, effective_date |
| `accounts` | name, type (cash/bank/ewallet/credit), icon, color, currency_code, opening_balance, include_in_total, sort_order, archived |
| `categories` | name, icon, color, type (expense/income), parent_id, sort_order |
| `transactions` | type (expense/income/transfer), amount, currency_code, account_id, to_account_id?, to_amount?, category_id?, occurred_at, note, event_id?, jar_id?, recurring_id? |
| `recurring_rules` | template (json), rrule, next_run_at |
| `attachments` | owner_type (transaction/event/post/message), owner_id, file_id, local_path, thumb_path, sort_order |
| `files` *(server)* | path, mime, size, width, height, thumb_path, uploader_id |
| `electricity_price_tables` | name, vat_percent, fixed_fee, is_default |
| `electricity_tiers` | table_id, from_kwh, to_kwh (nullable), price, order |
| `electricity_bills` | table_id, month, old_index, new_index, kwh, amount, transaction_id? |
| `budgets` | scope (total/category/account), ref_id?, period, limit_amount, currency_code, warn_percent |
| `savings_jars` | name, icon, target_amount, currency_code, deadline, cover_file_id |
| `jar_transactions` | jar_id, account_id, amount (+ nạp / − rút), note, occurred_at |
| `love_counter` | start_date, partner_name, partner_birthday, photos, milestone_reminder_days |
| `cycle_periods` | start_date, end_date, flow, note, subject (bản thân / người yêu) |
| `cycle_logs` | date, symptoms (json), mood, note |
| `cycle_settings` | default_cycle, default_period, luteal_days, fertile_before, fertile_after, reminders, sync_enabled |
| `events` | title, start_at, end_at, location, note, kind, color, rrule, remind_before_min, plan_id?, cover_file_id |
| `event_occurrence_photos` | event_id, occurrence_date, file_id, added_by (album theo từng lần lặp) |
| `event_participants` | event_id, user_id, status (invited/accepted/declined), role |
| `plans`, `plan_members` | title, description, owner_id |
| `users` *(server)* | email, password_hash, username, display_name, avatar_file_id, bio |
| `refresh_tokens`, `devices` *(server)* | token, expires_at · fcm_token, platform |
| `friendships` | requester_id, addressee_id, status (pending/accepted/blocked) |
| `conversations`, `conversation_members` | type (direct/group), name · last_read_message_id |
| `messages` | conversation_id, sender_id, content, type (text/image), client_sent_at, server_at |
| `posts` | author_id, content, visibility (friends/private/custom), event_id?, jar_id?, location |
| `post_audience` | post_id, user_id (khi visibility = custom) |
| `post_tags` | post_id, user_id |
| `comments` | post_id, author_id, parent_id?, content |
| `reactions` | target_type (post/comment), target_id, user_id, kind (like/love/haha/wow/sad/angry) |
| `notifications` *(server)* | user_id, type, payload, read_at |
| `app_settings` | menu_layout (json), theme, base_currency, finance_month_start_day… |
| *(local only)* `outbox`, `upload_queue`, `sync_state` | phục vụ đồng bộ |

Phân quyền ở API: người dùng chỉ đọc/ghi dữ liệu của mình; sự kiện/kế hoạch chung theo participant; tin nhắn theo thành viên hội thoại; bài viết theo `visibility` + quan hệ bạn bè.

---

## 8. Màn hình chính

1. **Trang chủ**: tổng số dư các tài khoản, thu/chi tháng + thanh định mức, lưới tiện ích (cấu hình được), giao dịch gần đây, mini đếm ngày yêu.
2. **Giao dịch**: toggle Danh sách ⇄ Lịch, bộ lọc, nút "+" nổi.
3. **Form thêm/sửa**: tab Chi / Thu / Chuyển khoản, bàn phím số lớn, chọn tài khoản + danh mục dạng lưới icon, chụp/chọn ảnh.
4. **Tài khoản**: danh sách ví với số dư, chi tiết lịch sử từng ví.
5. **Thống kê**: tab Tháng / Danh mục / Tài khoản / Năm, biểu đồ tương tác.
6. **Lịch trình**: timeline ngày + lịch tháng, album ảnh từng sự kiện, avatar người tham gia.
7. **Feed**: bài viết bạn bè, tạo bài, trang cá nhân.
8. **Tiện ích**: Tiền điện, Đếm ngày yêu, Kinh nguyệt, Hũ tiết kiệm, Định mức.
9. **Bạn bè & Chat**: hội thoại, lời mời, màn chat.
10. **Cài đặt**: tiền tệ & tỷ giá, danh mục, menu, thông báo, theme, bảo mật, tài khoản, trạng thái đồng bộ.

---

## 9. Quyết định đã chốt

| Câu hỏi | Quyết định |
|---|---|
| Nền tảng ưu tiên | **iOS** trước, Android dùng chung code Flutter |
| Ghi khoản thu | **Có** (Thu / Chi / Chuyển khoản) |
| Nhiều tài khoản/ví | **Có**, ngay từ Phase 1 |
| Tiền tệ | **Cấu hình được**, tiền tệ chính mặc định VND, tỷ giá nhập tay |
| Hạ tầng | **Tạm chạy local**: SQL Server trong Docker trên máy dev, chưa lên cloud |
| Backend | **ASP.NET Core (.NET 10) + SignalR + SQL Server + EF Core** |
| Đặt tên | Định danh tiếng Anh, mô tả + comment + thông báo lỗi tiếng Việt |
| Đăng nhập bắt buộc? | Không — dùng offline không cần tài khoản; đăng nhập khi muốn sync/xã hội |
| Đăng bài | **Có** (Feed bạn bè) |
| Ảnh cho lịch trình | **Có** (ảnh bìa + album, theo từng lần lặp) |

Còn mở: tên app chính thức; có cần Sign in with Apple ngay không; có Mac để build iOS hay dùng CI.

---

## 10. Quy ước API (tóm tắt)

- REST JSON, prefix `/api/v1`, camelCase, thời gian ISO-8601 UTC, tiền dùng `decimal` (server) / số nguyên đơn vị nhỏ nhất hoặc `Decimal` (app) — không dùng `double`.
- Phân trang: `?page=&pageSize=` hoặc `?cursor=&limit=`.
- Response: `{ "success": true, "data": …, "error": null }`; lỗi có `code` cố định để app dịch tiếng Việt.
- Upload: `POST /files` multipart, trả `{ id, url, thumbUrl }`.
- SignalR: `/hubs/chat`, `/hubs/presence`, `/hubs/notifications`.

---

## 11. Lộ trình

| Phase | Nội dung | Kết quả |
|---|---|---|
| **0. Khởi tạo** ✅ | Flutter project (iOS + Android), theme theo app cũ, router, Drift, Riverpod, bộ animation dùng chung · Solution .NET 4 lớp + base (BaseEntity, Repository, UoW, ApiResponse, middleware, OpenAPI, JWT, SignalR hubs), SQL Server Docker + migration đầu tiên ✅ | 2 bộ khung chạy được |
| **1. Lõi tài chính (offline)** ✅ | Tiền tệ & tỷ giá, tài khoản/ví, danh mục Thu/Chi 2 cấp, giao dịch thu/chi/chuyển khoản, ảnh đính kèm, xem danh sách + lịch, giao dịch định kỳ | Dùng hằng ngày được, chưa cần mạng |
| **2. Thống kê & Tiện ích** ✅ | Thống kê tháng/danh mục/tài khoản/năm, tiền điện, đếm ngày yêu, kinh nguyệt, định mức + cảnh báo, hũ tiết kiệm, menu cấu hình | Đủ tính năng cá nhân |
| **3. Lịch trình & Thông báo** ✅ | Sự kiện + lặp lại + album ảnh, timeline, local notification, widget iOS (WidgetKit) & Android | Nhắc nhở & widget |
| **4. Tài khoản & Đồng bộ** ✅ | Auth API (JWT/refresh), endpoints CRUD + `/sync`, upload file local, Sync Engine (outbox, upload queue, dọn cache), màn trạng thái sync | Dữ liệu lên server local, đổi máy không mất |
| **5. Xã hội realtime** ✅ | SignalR hubs (chat, presence, notifications), kết bạn, chat 1-1/nhóm, đăng bài + bình luận + cảm xúc, chia sẻ lịch trình & ảnh chung, FCM→APNs | Dùng cùng bạn bè, người yêu |
| **6. Hoàn thiện** | Kế hoạch chung + chia tiền, hũ chung, Face ID, xuất Excel, tối ưu hiệu năng, test, TestFlight; chuyển server lên cloud khi cần | Bản phát hành |

---

## 12. Trạng thái (20/11/2026)

Phase 0–5 đã làm và chạy được end-to-end trên web (xem README.md mục *Kiểm thử đã chạy*). Phân quyền động theo mô hình dự án NS_PhuSan (PhanHe/ChucNang/VaiTro). Tên bảng/cột SQL Server: tiếng Việt không dấu.
Còn lại: build iOS trên Mac, FCM/APNs thật, widget Android, Phase 6.

## 13. Việc cần làm ban đầu (đã xong phần lớn)

- [ ] Mở repo tham khảo, chụp lại các màn hình/màu chủ đạo, ghi vào `docs/ui-reference.md`.
- [ ] Cài Flutter SDK; chốt cách build iOS (Mac / CI) + tài khoản Apple Developer.
- [x] Solution .NET `server/` 4 lớp + base code backend.
- [x] SQL Server Docker + migration `InitialCreate` (37 bảng) + script `database/LHT_Money.sql`.
- [ ] `flutter create app` + khung Flutter (Phase 0 phần app).
- [ ] API Auth (đăng ký, đăng nhập, refresh token) + seed dữ liệu mặc định khi đăng ký (tiền tệ VND, tài khoản Tiền mặt, danh mục, bảng giá điện).
- [ ] Tạo Firebase project (chỉ dùng FCM/APNs) — có thể để tới Phase 5.
