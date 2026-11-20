using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Lịch trình / sự kiện")]
public class Event : OwnedEntity
{
    [Description("Tiêu đề")]
    public string Title { get; set; } = null!;

    [Description("Bắt đầu")]
    public DateTimeOffset StartAt { get; set; }

    [Description("Kết thúc")]
    public DateTimeOffset? EndAt { get; set; }

    [Description("Cả ngày")]
    public bool IsAllDay { get; set; }

    [Description("Địa điểm")]
    public string? Location { get; set; }

    [Description("Vĩ độ")]
    public double? Latitude { get; set; }

    [Description("Kinh độ")]
    public double? Longitude { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }

    [Description("Loại: 1=đi chơi, 2=công việc, 99=khác (cũ, nay dùng DanhMucId)")]
    public EventKind Kind { get; set; } = EventKind.Other;

    [Description("Danh mục lịch trình do người dùng cấu hình (DanhMuc loại 3)")]
    public Guid? CategoryId { get; set; }

    [Description("Màu (hex)")]
    public string? Color { get; set; }

    [Description("Quy tắc lặp RRULE, NULL = không lặp")]
    public string? RRule { get; set; }

    [Description("Lặp đến ngày")]
    public DateOnly? RepeatUntil { get; set; }

    [Description("Nhắc trước bao nhiêu phút, NULL = không nhắc")]
    public int? RemindBeforeMinutes { get; set; }

    [Description("Thuộc kế hoạch chung")]
    public Guid? PlanId { get; set; }

    [Description("Ảnh bìa (StoredFiles.Id)")]
    public Guid? CoverFileId { get; set; }

    [Description("Chi phí dự kiến")]
    public decimal? EstimatedCost { get; set; }

    [Description("Mã tiền tệ của chi phí")]
    public string? CurrencyCode { get; set; }
}
