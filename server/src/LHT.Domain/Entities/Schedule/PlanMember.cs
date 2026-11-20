using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Thành viên kế hoạch chung")]
public class PlanMember : BaseEntity
{
    [Description("Kế hoạch")]
    public Guid PlanId { get; set; }

    [Description("Thành viên")]
    public Guid MemberUserId { get; set; }

    [Description("Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem")]
    public MemberRole Role { get; set; } = MemberRole.Editor;

    [Description("Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối")]
    public ParticipantStatus Status { get; set; } = ParticipantStatus.Invited;
}
