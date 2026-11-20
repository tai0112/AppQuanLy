using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Người tham gia lịch trình chung")]
public class EventParticipant : BaseEntity
{
    [Description("Lịch trình")]
    public Guid EventId { get; set; }

    [Description("Người tham gia")]
    public Guid ParticipantUserId { get; set; }

    [Description("Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối")]
    public ParticipantStatus Status { get; set; } = ParticipantStatus.Invited;

    [Description("Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem")]
    public MemberRole Role { get; set; } = MemberRole.Editor;
}
