using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Báo cáo nội dung / người dùng vi phạm (yêu cầu của App Store với nội dung do người dùng tạo)")]
public class Report : BaseEntity
{
    [Description("Người gửi báo cáo")]
    public Guid ReporterId { get; set; }

    [Description("Loại đối tượng: 1 bài viết, 2 bình luận, 3 người dùng, 4 tin nhắn")]
    public ReportTarget TargetType { get; set; }

    [Description("Id đối tượng bị báo cáo")]
    public Guid TargetId { get; set; }

    [Description("Người bị báo cáo (chủ nội dung)")]
    public Guid? TargetUserId { get; set; }

    [Description("Lý do: 1 spam, 2 quấy rối, 3 tình dục, 4 bạo lực, 5 thù ghét, 6 lừa đảo, 99 khác")]
    public ReportReason Reason { get; set; }

    [Description("Mô tả thêm của người báo cáo")]
    public string? Note { get; set; }

    [Description("Trạng thái: 1 chờ xử lý, 2 đã gỡ nội dung, 3 bỏ qua")]
    public ReportStatus Status { get; set; } = ReportStatus.Open;

    [Description("Thời điểm xử lý")]
    public DateTimeOffset? HandledAt { get; set; }

    [Description("Quản trị viên xử lý")]
    public Guid? HandledByUserId { get; set; }
}
