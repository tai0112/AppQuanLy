namespace LHT.Application.Features.Permissions;

/// <summary>Dữ liệu seed: phân hệ, chức năng mặc định.</summary>
public static class PermissionCatalog
{
    public sealed record ModuleSeed(string Code, string Name, string Icon, int Order, OperationSeed[] Operations);
    public sealed record OperationSeed(string Code, string Name, string Route, string Icon, bool ForUser = true);

    public static readonly ModuleSeed[] Modules =
    [
        new("TAI_CHINH", "Tài chính", "account_balance_wallet", 1,
        [
            new(Perm.GiaoDich, "Giao dịch", "/transactions", "receipt_long"),
            new(Perm.TaiKhoan, "Tài khoản", "/accounts", "account_balance"),
            new(Perm.ThongKe, "Thống kê", "/stats", "pie_chart"),
            new(Perm.DanhMuc, "Danh mục", "/categories", "category"),
            new(Perm.DinhMuc, "Định mức", "/budgets", "speed"),
            new(Perm.HuTietKiem, "Hũ tiết kiệm", "/jars", "savings"),
        ]),
        new("TIEN_ICH", "Tiện ích", "widgets", 2,
        [
            new(Perm.TienDien, "Tiền điện", "/electricity", "bolt"),
            new(Perm.NgayYeu, "Ngày yêu", "/love", "favorite"),
            new(Perm.ChuKy, "Chu kỳ", "/cycle", "water_drop"),
            new(Perm.NhacNho, "Nhắc nhở", "/reminders", "alarm"),
        ]),
        new("LICH_TRINH", "Lịch trình", "event", 3,
        [
            new(Perm.LichTrinh, "Lịch trình", "/schedule", "event"),
        ]),
        new("XA_HOI", "Xã hội", "people", 4,
        [
            new(Perm.BaiViet, "Bảng tin", "/feed", "dynamic_feed"),
            new(Perm.TinNhan, "Tin nhắn", "/chat", "chat"),
            new(Perm.BanBe, "Bạn bè", "/friends", "group"),
        ]),
        new("QUAN_TRI", "Quản trị", "admin_panel_settings", 9,
        [
            new(Perm.QuanTriVaiTro, "Vai trò & phân quyền", "/admin/roles", "admin_panel_settings", false),
            new(Perm.QuanTriNguoiDung, "Người dùng", "/admin/users", "manage_accounts", false),
            new(Perm.QuanTriChucNang, "Chức năng", "/admin/operations", "tune", false),
            new(Perm.QuanTriBaoCao, "Báo cáo vi phạm", "/admin/reports", "flag", false),
        ]),
    ];
}
