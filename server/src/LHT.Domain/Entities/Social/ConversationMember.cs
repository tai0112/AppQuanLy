using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Thành viên hội thoại")]
public class ConversationMember : BaseEntity
{
    [Description("Hội thoại")]
    public Guid ConversationId { get; set; }

    [Description("Thành viên")]
    public Guid MemberUserId { get; set; }

    [Description("Vai trò: 1=chủ, 2=thành viên")]
    public MemberRole Role { get; set; } = MemberRole.Editor;

    [Description("Tin nhắn đã đọc gần nhất")]
    public Guid? LastReadMessageId { get; set; }

    [Description("Tin nhắn đã nhận gần nhất")]
    public Guid? LastDeliveredMessageId { get; set; }

    [Description("Tắt thông báo")]
    public bool IsMuted { get; set; }
}
