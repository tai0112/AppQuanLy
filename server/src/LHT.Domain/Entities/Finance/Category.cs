using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Danh mục thu/chi (2 cấp)")]
public class Category : OwnedEntity
{
    [Description("Tên danh mục")]
    public string Name { get; set; } = null!;

    [Description("Loại: 1=chi, 2=thu, 3=lịch trình, 4=mẫu hoạt động trong ngày")]
    public CategoryType Type { get; set; }

    [Description("Danh mục cha, NULL = danh mục cấp 1")]
    public Guid? ParentId { get; set; }

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Màu (hex)")]
    public string? Color { get; set; }

    [Description("Thứ tự sắp xếp")]
    public int SortOrder { get; set; }

    [System.Text.Json.Serialization.JsonIgnore] public Category? Parent { get; set; }
}
