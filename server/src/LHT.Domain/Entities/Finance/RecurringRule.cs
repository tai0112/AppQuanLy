using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Giao dịch định kỳ (tiền nhà, lương...)")]
public class RecurringRule : OwnedEntity
{
    [Description("Tên quy tắc")]
    public string Name { get; set; } = null!;

    [Description("Mẫu giao dịch (JSON)")]
    public string TemplateJson { get; set; } = null!;

    [Description("Quy tắc lặp theo chuẩn RRULE (RFC 5545)")]
    public string RRule { get; set; } = null!;

    [Description("Lần chạy kế tiếp")]
    public DateTimeOffset NextRunAt { get; set; }

    [Description("Đang bật")]
    public bool IsActive { get; set; } = true;
}
