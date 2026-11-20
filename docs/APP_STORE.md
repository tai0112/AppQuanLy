# Đưa LHT Money lên App Store

## A. Những gì đã làm sẵn trong code

| Yêu cầu của Apple | Điều khoản | Đã làm | Ở đâu |
|---|---|---|---|
| Xoá tài khoản ngay trong app | 5.1.1(v) | Cài đặt → **Xoá tài khoản**: nhập lại mật khẩu, xoá vĩnh viễn dữ liệu và ảnh trên máy chủ, dọn sạch máy | `AccountService.cs`, `POST /api/v1/me/delete`, `DeleteAccountPage` |
| Giải thích quyền máy ảnh / ảnh | 5.1.1 | Câu mô tả cụ thể (kèm ví dụ) trong Info.plist; bảng chọn ảnh ghi rõ mục đích; bị từ chối quyền thì hướng dẫn bật lại | `ios/Runner/Info.plist`, `pickPhotos()` |
| Chỉ hỏi quyền khi cần | 5.1.1 | Máy ảnh / thư viện chỉ được hỏi khi người dùng bấm "Chụp ảnh" / "Chọn từ thư viện" | `pickPhotos()` |
| Nội dung do người dùng tạo (bài viết, bình luận, chat) | 1.2 | **Báo cáo** bài viết / bình luận / tin nhắn / người dùng; **Chặn** người dùng; bắt buộc **đồng ý điều khoản** "không dung thứ nội dung phản cảm" khi đăng ký; nội dung bị báo cáo ẩn ngay với người báo cáo; trang quản trị xử lý báo cáo | `ModerationService.cs`, `moderation.dart` |
| Chính sách quyền riêng tư | 5.1.1(i) | Có trong app (Cài đặt) **và** trên web `/privacy.html`, `/terms.html` (cùng một nội dung) | `app/assets/legal/legal.json`, `app/web/*.html` |
| Privacy manifest | từ 05/2024 | `PrivacyInfo.xcprivacy`: dữ liệu thu thập, không theo dõi, lý do dùng UserDefaults / FileTimestamp | `ios/Runner/PrivacyInfo.xcprivacy` |
| Khai báo mã hoá | Export compliance | `ITSAppUsesNonExemptEncryption = false` (chỉ dùng HTTPS) | Info.plist |
| Cảnh báo y tế | 1.4.1 | Màn Chu kỳ ghi rõ "chỉ mang tính tham khảo, không dùng để tránh thai" | `cycle.dart`, Điều khoản mục 5 |
| Tên hiển thị, ngôn ngữ | — | "LHT Money", ngôn ngữ vi; chỉ iPhone, màn hình dọc | Info.plist, project.pbxproj |

Cách xoá tài khoản hoạt động:
- **Xoá vĩnh viễn:** giao dịch, tài khoản tiền, danh mục, định mức, hũ, lịch trình, ảnh, chu kỳ, cài đặt, bài viết, bạn bè, phiên đăng nhập. File ảnh cũng bị xoá khỏi ổ đĩa.
- **Bình luận và tin nhắn đã gửi cho người khác:** bị xoá nội dung.
- **Hồ sơ:** được ẩn danh hoá. Email và tên đăng nhập được giải phóng để đăng ký lại.
- **Token cũ:** không đồng bộ ghi dữ liệu được nữa.

## B. Những việc bạn phải tự làm

1. **Tài khoản Apple Developer** (99 USD/năm). Sau đó tạo app trong App Store Connect với Bundle ID `vn.lht.lhtMoney` (hoặc đổi trong Xcode).
2. **Đưa máy chủ lên Internet có HTTPS** (tên miền thật). iOS chặn kết nối `http://`, và người duyệt của Apple phải kết nối được trong suốt thời gian duyệt.
   Build bản phát hành trỏ tới máy chủ đó:
   ```bash
   cd app
   flutter build ipa --release --dart-define=API_URL=https://api.ten-mien-cua-ban.vn
   ```
3. **Điền email hỗ trợ thật.** Trong `app/assets/legal/legal.json`, đổi `"contact": "hotro@example.com"`. Đổi cả ngày `updated` nếu sửa nội dung.
4. **Khai báo trong App Store Connect:**
   - Privacy Policy URL: `https://<tên-miền>/privacy.html`
   - Support URL: trang liên hệ hoặc chính trang trên
   - **App Privacy:**

     | Loại dữ liệu | Thu thập | Gắn với danh tính | Theo dõi | Mục đích |
     |---|---|---|---|---|
     | Email Address, Name, User ID | Có | Có | Không | App Functionality |
     | Photos or Videos | Có | Có | Không | App Functionality |
     | Other User Content (bài viết, tin nhắn) | Có | Có | Không | App Functionality |
     | Other Financial Info | Có | Có | Không | App Functionality |
     | Health (chu kỳ, chỉ khi bật đồng bộ) | Có | Có | Không | App Functionality |
     | Device ID (thông báo) | Có | Có | Không | App Functionality |

   - **Age Rating:** trả lời đúng. App có nội dung do người dùng tạo và có nhắn tin.
5. **Ghi chú cho người duyệt (App Review Information):**
   - Tạo một tài khoản demo riêng có sẵn dữ liệu (đừng dùng tài khoản cá nhân), rồi ghi tên đăng nhập và mật khẩu vào đây.
   - Ghi kèm hướng dẫn ngắn:
     > Báo cáo / chặn: menu ⋯ trên bài viết, nhấn giữ bình luận / tin nhắn, menu ⋯ trong khung chat và danh sách bạn bè.
     > Xoá tài khoản: Cài đặt → Xoá tài khoản.
     > Máy ảnh chỉ dùng để chụp hoá đơn / ảnh đính kèm khi người dùng bấm "Chụp ảnh".
     > Báo cáo vi phạm được quản trị viên xử lý trong 24 giờ.
6. **Xử lý báo cáo trong 24 giờ:** đây là cam kết trong Điều khoản. Tài khoản quản trị vào Cài đặt → **Báo cáo vi phạm (quản trị)** để gỡ nội dung hoặc bỏ qua.
7. **Ảnh chụp màn hình:** iPhone 6.9" (1320×2868) là bắt buộc. Thêm biểu tượng 1024×1024 không có nền trong suốt.
8. **Widget iOS** (nếu dùng): bật App Group `group.vn.lht.money` cho cả Runner lẫn widget, xem `docs/WIDGET_IOS.md`.
9. **Không cần "Sign in with Apple":** app chỉ dùng tài khoản riêng, không đăng nhập bằng Google / Facebook. Nếu sau này thêm đăng nhập mạng xã hội thì bắt buộc phải có.
10. **Muốn hỗ trợ iPad:** đổi `TARGETED_DEVICE_FAMILY` về `"1,2"`. Khi đó phải có thêm ảnh chụp iPad và giao diện phải dùng tốt trên iPad.
