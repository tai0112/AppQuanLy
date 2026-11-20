using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Lịch sử tiền điện từng kỳ")]
public class ElectricityBill : OwnedEntity
{
    [Description("Công tơ (NULL = hoá đơn tổng EVN của cả nhà)")]
    public Guid? MeterId { get; set; }

    [Description("Bảng giá đã dùng")]
    public Guid PriceTableId { get; set; }

    [Description("Kỳ (ngày đầu tháng)")]
    public DateOnly Period { get; set; }

    [Description("Chỉ số cũ")]
    public int? OldIndex { get; set; }

    [Description("Chỉ số mới")]
    public int? NewIndex { get; set; }

    [Description("Số kWh tiêu thụ")]
    public int Kwh { get; set; }

    [Description("Số tiền (đã gồm VAT, phí)")]
    public decimal Amount { get; set; }

    [Description("Chi tiết từng bậc (JSON)")]
    public string? BreakdownJson { get; set; }

    [Description("Giao dịch đã tạo từ hoá đơn này")]
    public Guid? TransactionId { get; set; }
}
