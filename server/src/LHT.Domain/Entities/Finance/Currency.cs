using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Tiền tệ người dùng cấu hình")]
public class Currency : OwnedEntity
{
    [Description("Mã ISO 4217, vd VND, USD")]
    public string Code { get; set; } = null!;

    [Description("Tên tiền tệ")]
    public string Name { get; set; } = null!;

    [Description("Ký hiệu, vd ₫, $")]
    public string Symbol { get; set; } = null!;

    [Description("Số chữ số thập phân hiển thị (VND = 0)")]
    public byte Decimals { get; set; }

    [Description("Vị trí ký hiệu: 1=sau số, 2=trước số")]
    public SymbolPosition SymbolPosition { get; set; } = SymbolPosition.After;

    [Description("Là tiền tệ chính để quy đổi thống kê")]
    public bool IsBase { get; set; }
}
