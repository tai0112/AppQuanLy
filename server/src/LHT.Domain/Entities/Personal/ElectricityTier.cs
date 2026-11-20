using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Một bậc trong bảng giá điện")]
public class ElectricityTier : OwnedEntity
{
    [Description("Bảng giá")]
    public Guid PriceTableId { get; set; }

    [Description("Thứ tự bậc (1, 2, 3...)")]
    public int TierOrder { get; set; }

    [Description("Từ kWh (bao gồm)")]
    public int FromKwh { get; set; }

    [Description("Đến kWh (bao gồm), NULL = không giới hạn")]
    public int? ToKwh { get; set; }

    [Description("Đơn giá (đồng/kWh)")]
    public decimal Price { get; set; }
}
