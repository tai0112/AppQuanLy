using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Bài viết")]
public class Post : BaseEntity
{
    [Description("Tác giả")]
    public Guid AuthorId { get; set; }

    [Description("Nội dung")]
    public string? Content { get; set; }

    [Description("Quyền xem: 1=bạn bè, 2=chỉ mình tôi, 3=chọn người")]
    public PostVisibility Visibility { get; set; } = PostVisibility.Friends;

    [Description("Gắn lịch trình")]
    public Guid? EventId { get; set; }

    [Description("Gắn hũ tiết kiệm")]
    public Guid? JarId { get; set; }

    [Description("Địa điểm")]
    public string? Location { get; set; }

    [Description("Cảm xúc / trạng thái")]
    public string? Feeling { get; set; }

    [Description("Số cảm xúc (đếm sẵn)")]
    public int ReactionCount { get; set; }

    [Description("Số bình luận (đếm sẵn)")]
    public int CommentCount { get; set; }
}
