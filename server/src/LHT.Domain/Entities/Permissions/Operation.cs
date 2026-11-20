using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Chức năng / quyền (cũng là mục menu nếu IsShow)")]
public class Operation : BaseEntity
{
    [Description("Phân hệ")]
    public Guid ModuleId { get; set; }

    [Description("Chức năng cha (menu nhiều cấp)")]
    public Guid? ParentId { get; set; }

    [Description("Mã chức năng duy nhất, vd QUAN_TRI.VAI_TRO")]
    public string Code { get; set; } = null!;

    [Description("Tên chức năng")]
    public string Name { get; set; } = null!;

    [Description("Đường dẫn màn hình trên app, vd /admin/roles")]
    public string? Route { get; set; }

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }

    [Description("Hiện trên menu")]
    public bool IsShow { get; set; } = true;
}
