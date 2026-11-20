using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Bình luận")]
public class Comment : BaseEntity
{
    [Description("Bài viết")]
    public Guid PostId { get; set; }

    [Description("Người bình luận")]
    public Guid AuthorId { get; set; }

    [Description("Bình luận cha (trả lời 1 cấp)")]
    public Guid? ParentId { get; set; }

    [Description("Nội dung")]
    public string Content { get; set; } = null!;
}
