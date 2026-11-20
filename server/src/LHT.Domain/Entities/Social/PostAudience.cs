using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Người được xem bài viết (khi quyền xem = chọn người)")]
public class PostAudience : BaseEntity
{
    [Description("Bài viết")]
    public Guid PostId { get; set; }

    [Description("Người được xem")]
    public Guid ViewerUserId { get; set; }
}
