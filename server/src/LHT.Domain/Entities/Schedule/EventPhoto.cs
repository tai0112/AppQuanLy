using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Ảnh album của lịch trình (theo từng lần lặp)")]
public class EventPhoto : BaseEntity
{
    [Description("Lịch trình")]
    public Guid EventId { get; set; }

    [Description("Ngày của lần lặp (NULL nếu lịch không lặp)")]
    public DateOnly? OccurrenceDate { get; set; }

    [Description("Hoạt động trong lịch trình (NULL = ảnh chung của album)")]
    public Guid? EventItemId { get; set; }

    [Description("File ảnh (StoredFiles.Id)")]
    public Guid FileId { get; set; }

    [Description("Người thêm ảnh")]
    public Guid AddedByUserId { get; set; }

    [Description("Chú thích")]
    public string? Caption { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }
}
