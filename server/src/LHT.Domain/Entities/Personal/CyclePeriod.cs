using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Kỳ kinh nguyệt")]
public class CyclePeriod : OwnedEntity
{
    [Description("Theo dõi cho: 1=bản thân, 2=người yêu")]
    public CycleSubject Subject { get; set; } = CycleSubject.Self;

    [Description("Ngày bắt đầu hành kinh")]
    public DateOnly StartDate { get; set; }

    [Description("Ngày kết thúc hành kinh")]
    public DateOnly? EndDate { get; set; }

    [Description("Lượng máu: 1=ít, 2=vừa, 3=nhiều")]
    public CycleFlow? Flow { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }
}
