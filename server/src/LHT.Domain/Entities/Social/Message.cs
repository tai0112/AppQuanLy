using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Tin nhắn")]
public class Message : BaseEntity
{
    [Description("Hội thoại")]
    public Guid ConversationId { get; set; }

    [Description("Người gửi")]
    public Guid SenderId { get; set; }

    [Description("Loại: 1=chữ, 2=ảnh, 3=hệ thống")]
    public MessageType Type { get; set; } = MessageType.Text;

    [Description("Nội dung")]
    public string? Content { get; set; }

    [Description("Trả lời tin nhắn")]
    public Guid? ReplyToMessageId { get; set; }

    [Description("Thời điểm gửi trên máy (có thể lúc offline)")]
    public DateTimeOffset ClientSentAt { get; set; }

    [Description("Thời điểm server nhận")]
    public DateTimeOffset ServerReceivedAt { get; set; }
}
