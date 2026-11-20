using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Bạn bè được tag trong bài viết")]
public class PostTag : BaseEntity
{
    [Description("Bài viết")]
    public Guid PostId { get; set; }

    [Description("Người được tag")]
    public Guid TaggedUserId { get; set; }
}
