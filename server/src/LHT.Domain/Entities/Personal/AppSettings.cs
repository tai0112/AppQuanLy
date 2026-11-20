using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Cài đặt app của người dùng")]
public class AppSettings : OwnedEntity
{
    [Description("Bố cục menu, tiện ích trang chủ (JSON)")]
    public string? MenuLayoutJson { get; set; }

    [Description("Giao diện: system/light/dark")]
    public string Theme { get; set; } = "system";

    [Description("Màu chủ đạo (hex)")]
    public string? PrimaryColor { get; set; }

    [Description("Mã tiền tệ chính")]
    public string BaseCurrencyCode { get; set; } = "VND";

    [Description("Ngày bắt đầu tháng tài chính (1-28)")]
    public byte FinanceMonthStartDay { get; set; } = 1;

    [Description("Ngày đầu tuần: 1=Thứ hai, 7=Chủ nhật")]
    public byte FirstDayOfWeek { get; set; } = 1;

    [Description("Cấu hình thông báo (JSON)")]
    public string? NotificationJson { get; set; }

    [Description("Tài khoản/ví mặc định khi thêm giao dịch (NULL = tài khoản đầu tiên)")]
    public Guid? DefaultAccountId { get; set; }

    [Description("Tự chọn tài khoản đã dùng ở giao dịch trước")]
    public bool RememberLastAccount { get; set; }

    [Description("Cấu hình thời gian (JSON): các mốc nhắc, nhắc mặc định, khung giờ timeline, bước làm tròn, thời lượng hoạt động mặc định")]
    public string? TimeConfigJson { get; set; }
}
