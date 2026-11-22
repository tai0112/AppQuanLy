using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Nhắc nhở do người dùng tự đặt (uống nước, uống thuốc...)")]
public class Reminder : OwnedEntity
{
    [Description("Nội dung nhắc")]
    public string Title { get; set; } = null!;

    [Description("Ghi chú")]
    public string? Note { get; set; }

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Màu (hex)")]
    public string? Color { get; set; }

    [Description("Lặp lại: 1=hằng ngày, 2=theo thứ trong tuần, 3=từng ngày cụ thể")]
    public ReminderRepeat RepeatMode { get; set; } = ReminderRepeat.Daily;

    [Description("Các giờ nhắc trong ngày, vd 07:30,21:00")]
    public string Times { get; set; } = null!;

    [Description("Các thứ nhắc khi lặp theo thứ: 1=Thứ 2 ... 7=Chủ nhật, vd 1,3,5")]
    public string? Weekdays { get; set; }

    [Description("Các ngày nhắc khi chọn từng ngày, vd 2026-11-25,2026-11-28")]
    public string? Dates { get; set; }

    [Description("Đang bật")]
    public bool IsActive { get; set; } = true;

    [Description("Thứ tự sắp xếp")]
    public int SortOrder { get; set; }
}
