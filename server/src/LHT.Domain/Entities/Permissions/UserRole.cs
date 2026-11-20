using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Vai trò của người dùng")]
public class UserRole : BaseEntity
{
    [Description("Người dùng")]
    public Guid MemberUserId { get; set; }

    [Description("Vai trò")]
    public Guid RoleId { get; set; }
}
