using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Cấu hình theo dõi chu kỳ")]
public class CycleSettings : OwnedEntity
{
    [Description("Theo dõi cho: 1=bản thân, 2=người yêu")]
    public CycleSubject Subject { get; set; } = CycleSubject.Self;

    [Description("Độ dài chu kỳ mặc định (ngày)")]
    public int DefaultCycleDays { get; set; } = 28;

    [Description("Số ngày hành kinh mặc định")]
    public int DefaultPeriodDays { get; set; } = 5;

    [Description("Pha hoàng thể (ngày từ rụng trứng tới kỳ sau)")]
    public int LutealDays { get; set; } = 14;

    [Description("Số ngày dễ thụ thai trước rụng trứng")]
    public int FertileDaysBefore { get; set; } = 5;

    [Description("Số ngày dễ thụ thai sau rụng trứng")]
    public int FertileDaysAfter { get; set; } = 1;

    [Description("Cấu hình nhắc nhở (JSON)")]
    public string? RemindersJson { get; set; }

    [Description("Cho phép đồng bộ dữ liệu chu kỳ lên server")]
    public bool SyncEnabled { get; set; }

    [Description("Chia sẻ cho người yêu xem")]
    public bool ShareWithPartner { get; set; }
}
