using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Tỷ giá nhập tay theo ngày")]
public class ExchangeRate : OwnedEntity
{
    [Description("Mã tiền tệ nguồn")]
    public string FromCode { get; set; } = null!;

    [Description("Mã tiền tệ đích")]
    public string ToCode { get; set; } = null!;

    [Description("1 đơn vị nguồn = Rate đơn vị đích")]
    public decimal Rate { get; set; }

    [Description("Ngày bắt đầu áp dụng")]
    public DateOnly EffectiveDate { get; set; }
}
