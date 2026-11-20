# Thêm widget màn hình chính iOS

Cần máy Mac có Xcode.

1. `cd app && flutter build ios --config-only` rồi mở `ios/Runner.xcworkspace` bằng Xcode.
2. **File → New → Target → Widget Extension**, đặt tên `LHTWidget`, bỏ chọn "Include Configuration Intent".
3. Thay nội dung file Swift Xcode vừa tạo bằng [app/ios/LHTWidget/LHTWidget.swift](../app/ios/LHTWidget/LHTWidget.swift).
4. Chọn target **Runner** → *Signing & Capabilities* → **+ App Groups** → `group.vn.lht.money`.
   Làm tương tự cho target **LHTWidget**.
5. Build lại app. App Flutter ghi dữ liệu (`month_expense`, `month_income`, `love_days`, `today_events`) mỗi khi dữ liệu thay đổi và gọi `HomeWidget.updateWidget(iOSName: 'LHTWidget')` — xem `lib/data/background.dart`.
6. Trên iPhone: giữ màn hình chính → **+** → tìm "LHT Money".
