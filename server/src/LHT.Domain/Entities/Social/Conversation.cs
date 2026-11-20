using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Hội thoại chat")]
public class Conversation : BaseEntity
{
    [Description("Loại: 1=1-1, 2=nhóm")]
    public ConversationType Type { get; set; }

    [Description("Tên nhóm")]
    public string? Name { get; set; }

    [Description("Ảnh nhóm (StoredFiles.Id)")]
    public Guid? AvatarFileId { get; set; }

    [Description("Người tạo")]
    public Guid CreatedByUserId { get; set; }

    [Description("Tin nhắn cuối (để sắp xếp danh sách)")]
    public Guid? LastMessageId { get; set; }

    [Description("Thời điểm tin nhắn cuối")]
    public DateTimeOffset? LastMessageAt { get; set; }
}
