using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Chức năng được cấp cho vai trò")]
public class RoleOperation : BaseEntity
{
    [Description("Vai trò")]
    public Guid RoleId { get; set; }

    [Description("Chức năng")]
    public Guid OperationId { get; set; }
}
