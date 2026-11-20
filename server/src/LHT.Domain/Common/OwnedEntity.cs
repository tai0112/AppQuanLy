using System.ComponentModel;

namespace LHT.Domain.Common;

/// <summary>Bảng thuộc về một người dùng cụ thể.</summary>
public abstract class OwnedEntity : BaseEntity
{
    [Description("Người dùng sở hữu bản ghi")]
    public Guid UserId { get; set; }
}
