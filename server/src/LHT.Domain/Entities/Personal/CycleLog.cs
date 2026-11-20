using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Nhật ký triệu chứng hằng ngày")]
public class CycleLog : OwnedEntity
{
    [Description("Theo dõi cho: 1=bản thân, 2=người yêu")]
    public CycleSubject Subject { get; set; } = CycleSubject.Self;

    [Description("Ngày ghi")]
    public DateOnly Date { get; set; }

    [Description("Triệu chứng (JSON mảng mã)")]
    public string? SymptomsJson { get; set; }

    [Description("Tâm trạng")]
    public string? Mood { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }
}
