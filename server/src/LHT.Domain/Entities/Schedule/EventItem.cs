using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Hoạt động theo giờ trong lịch trình (timeline trong ngày)")]
public class EventItem : BaseEntity
{
    [Description("Lịch trình")]
    public Guid EventId { get; set; }

    [Description("Ngày của hoạt động; NULL = áp dụng cho mọi lần lặp")]
    public DateOnly? OccurrenceDate { get; set; }

    [Description("Giờ bắt đầu")]
    public TimeOnly StartTime { get; set; }

    [Description("Giờ kết thúc")]
    public TimeOnly? EndTime { get; set; }

    [Description("Tên hoạt động, vd Ăn sáng, Tham quan")]
    public string Title { get; set; } = null!;

    [Description("Địa điểm")]
    public string? Location { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }

    [Description("Chi phí dự kiến")]
    public decimal? Cost { get; set; }

    [Description("Đã hoàn thành")]
    public bool IsDone { get; set; }

    [Description("Biểu tượng")]
    public string? Icon { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }

    [Description("Người thêm")]
    public Guid AddedByUserId { get; set; }
}
