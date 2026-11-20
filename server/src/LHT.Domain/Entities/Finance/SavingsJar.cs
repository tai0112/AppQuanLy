using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Hũ tiết kiệm")]
public class SavingsJar : OwnedEntity
{
    [Description("Tên hũ")]
    public string Name { get; set; } = null!;

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Màu (hex)")]
    public string? Color { get; set; }

    [Description("Số tiền mục tiêu")]
    public decimal TargetAmount { get; set; }

    [Description("Mã tiền tệ")]
    public string CurrencyCode { get; set; } = null!;

    [Description("Hạn hoàn thành")]
    public DateOnly? Deadline { get; set; }

    [Description("Ảnh bìa (StoredFiles.Id)")]
    public Guid? CoverFileId { get; set; }

    [Description("Đã hoàn thành / đóng hũ")]
    public bool IsClosed { get; set; }
}
