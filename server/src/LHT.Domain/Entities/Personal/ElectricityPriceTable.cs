using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Bảng giá điện bậc thang")]
public class ElectricityPriceTable : OwnedEntity
{
    [Description("Tên bảng giá, vd EVN sinh hoạt 2025")]
    public string Name { get; set; } = null!;

    [Description("Thuế VAT (%)")]
    public decimal VatPercent { get; set; }

    [Description("Phí cố định mỗi kỳ")]
    public decimal FixedFee { get; set; }

    [Description("Bảng giá mặc định")]
    public bool IsDefault { get; set; }

    [System.Text.Json.Serialization.JsonIgnore] public List<ElectricityTier> Tiers { get; set; } = [];
}
