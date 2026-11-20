using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Lịch sử nạp / rút hũ tiết kiệm")]
public class JarTransaction : OwnedEntity
{
    [Description("Hũ tiết kiệm")]
    public Guid JarId { get; set; }

    [Description("Tài khoản lấy tiền / nhận tiền")]
    public Guid? AccountId { get; set; }

    [Description("Số tiền: dương = nạp, âm = rút")]
    public decimal Amount { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }

    [Description("Thời điểm nạp/rút")]
    public DateTimeOffset OccurredAt { get; set; }

    [System.Text.Json.Serialization.JsonIgnore] public SavingsJar? Jar { get; set; }
}
