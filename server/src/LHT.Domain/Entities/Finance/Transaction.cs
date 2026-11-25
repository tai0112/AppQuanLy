using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Giao dịch thu / chi / chuyển khoản")]
public class Transaction : OwnedEntity
{
    [Description("Loại: 1=chi, 2=thu, 3=chuyển khoản")]
    public TransactionType Type { get; set; }

    [Description("Số tiền (luôn dương) theo tiền tệ của tài khoản nguồn")]
    public decimal Amount { get; set; }

    [Description("Mã tiền tệ của số tiền")]
    public string CurrencyCode { get; set; } = null!;

    [Description("Tài khoản nguồn")]
    public Guid AccountId { get; set; }

    [Description("Tài khoản nhận (chỉ khi chuyển khoản)")]
    public Guid? ToAccountId { get; set; }

    [Description("Số tiền tài khoản nhận được (khi khác tiền tệ)")]
    public decimal? ToAmount { get; set; }

    [Description("Danh mục (NULL khi chuyển khoản)")]
    public Guid? CategoryId { get; set; }

    [Description("Thời điểm phát sinh")]
    public DateTimeOffset OccurredAt { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }

    [Description("Địa điểm")]
    public string? Location { get; set; }

    [Description("Vĩ độ")]
    public double? Latitude { get; set; }

    [Description("Kinh độ")]
    public double? Longitude { get; set; }

    [Description("Gắn với lịch trình")]
    public Guid? EventId { get; set; }

    [Description("Gắn với hũ tiết kiệm")]
    public Guid? JarId { get; set; }

    [Description("Sinh ra từ giao dịch định kỳ")]
    public Guid? RecurringRuleId { get; set; }

    [System.Text.Json.Serialization.JsonIgnore] public Account? Account { get; set; }
    [System.Text.Json.Serialization.JsonIgnore] public Category? Category { get; set; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? CategoryName { get; set; }

    [System.ComponentModel.DataAnnotations.Schema.NotMapped]
    public string? AccountName { get; set; }
}
