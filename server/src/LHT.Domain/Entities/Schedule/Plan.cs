using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Kế hoạch chung (vd chuyến du lịch) gồm nhiều lịch trình")]
public class Plan : OwnedEntity
{
    [Description("Tên kế hoạch")]
    public string Title { get; set; } = null!;

    [Description("Mô tả")]
    public string? Description { get; set; }

    [Description("Ảnh bìa (StoredFiles.Id)")]
    public Guid? CoverFileId { get; set; }

    [Description("Ngày bắt đầu")]
    public DateOnly? StartDate { get; set; }

    [Description("Ngày kết thúc")]
    public DateOnly? EndDate { get; set; }
}
