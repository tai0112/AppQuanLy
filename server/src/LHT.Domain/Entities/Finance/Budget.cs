using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Định mức chi tiêu")]
public class Budget : OwnedEntity
{
    [Description("Tên định mức")]
    public string Name { get; set; } = null!;

    [Description("Phạm vi: 1=tổng, 2=danh mục, 3=tài khoản")]
    public BudgetScope Scope { get; set; }

    [Description("Id danh mục/tài khoản tương ứng phạm vi")]
    public Guid? RefId { get; set; }

    [Description("Chu kỳ: 1=ngày, 2=tuần, 3=tháng, 4=năm")]
    public BudgetPeriod Period { get; set; } = BudgetPeriod.Month;

    [Description("Hạn mức")]
    public decimal LimitAmount { get; set; }

    [Description("Mã tiền tệ của hạn mức")]
    public string CurrencyCode { get; set; } = null!;

    [Description("Ngưỡng cảnh báo sắp vượt (%), mặc định 80")]
    public byte WarnPercent { get; set; } = 80;

    [Description("Đang bật")]
    public bool IsActive { get; set; } = true;
}
