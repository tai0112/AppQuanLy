using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Cảm xúc (like, tim...)")]
public class Reaction : BaseEntity
{
    [Description("Đối tượng: 1=bài viết, 2=bình luận")]
    public ReactionTarget TargetType { get; set; }

    [Description("Id bài viết / bình luận")]
    public Guid TargetId { get; set; }

    [Description("Người thả cảm xúc")]
    public Guid ReactorUserId { get; set; }

    [Description("Loại: 1=like, 2=tim, 3=haha, 4=wow, 5=buồn, 6=giận")]
    public ReactionKind Kind { get; set; } = ReactionKind.Like;
}
