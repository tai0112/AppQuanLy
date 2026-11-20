using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Thông báo trong app")]
public class Notification : OwnedEntity
{
    [Description("Loại thông báo")]
    public NotificationType Type { get; set; }

    [Description("Người gây ra thông báo")]
    public Guid? ActorUserId { get; set; }

    [Description("Tiêu đề")]
    public string Title { get; set; } = null!;

    [Description("Nội dung")]
    public string? Body { get; set; }

    [Description("Dữ liệu điều hướng (JSON)")]
    public string? PayloadJson { get; set; }

    [Description("Thời điểm đã đọc")]
    public DateTimeOffset? ReadAt { get; set; }
}
