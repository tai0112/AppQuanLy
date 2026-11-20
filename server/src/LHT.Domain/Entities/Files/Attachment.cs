using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Ảnh đính kèm cho giao dịch / lịch trình / bài viết / tin nhắn...")]
public class Attachment : OwnedEntity
{
    [Description("Loại đối tượng: 1=giao dịch, 2=lịch trình, 3=bài viết, 4=tin nhắn, 5=hoá đơn điện, 6=hũ")]
    public AttachmentOwnerType OwnerType { get; set; }

    [Description("Id đối tượng sở hữu ảnh")]
    public Guid OwnerId { get; set; }

    [Description("File (StoredFiles.Id)")]
    public Guid FileId { get; set; }

    [Description("Chú thích ảnh")]
    public string? Caption { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }

    [System.Text.Json.Serialization.JsonIgnore] public StoredFile? File { get; set; }
}
