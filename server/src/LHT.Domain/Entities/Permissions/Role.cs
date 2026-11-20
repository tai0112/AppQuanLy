using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Vai trò")]
public class Role : BaseEntity
{
    [Description("Mã vai trò, vd ADMIN, USER")]
    public string Code { get; set; } = null!;

    [Description("Tên vai trò")]
    public string Name { get; set; } = null!;

    [Description("Mô tả")]
    public string? Description { get; set; }

    [Description("Đang bật")]
    public bool IsActive { get; set; } = true;

    [Description("Vai trò hệ thống (không cho xoá)")]
    public bool IsSystem { get; set; }

    [Description("Tự gán cho người dùng mới đăng ký")]
    public bool IsDefault { get; set; }
}
