using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

// Phân quyền động (theo mô hình dự án NS_PhuSan): Phân hệ → Chức năng; Vai trò ↔ Chức năng; Người dùng ↔ Vai trò.
// Quyền kiểm tra theo Mã chức năng, ví dụ [HasPermission("QUAN_TRI.VAI_TRO")]. Gán quyền thay đổi lúc chạy, không cần build lại.

[Description("Phân hệ (nhóm chức năng)")]
public class Module : BaseEntity
{
    [Description("Mã phân hệ, vd QUAN_TRI")]
    public string Code { get; set; } = null!;

    [Description("Tên phân hệ")]
    public string Name { get; set; } = null!;

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }

    [Description("Hiện trên menu")]
    public bool IsShow { get; set; } = true;
}
