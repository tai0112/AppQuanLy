using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Người dùng")]
public class User : BaseEntity
{
    [Description("Email đăng nhập (duy nhất)")]
    public string Email { get; set; } = null!;

    [Description("Tên người dùng để tìm kiếm, kết bạn (duy nhất)")]
    public string Username { get; set; } = null!;

    [Description("Mật khẩu đã băm")]
    public string PasswordHash { get; set; } = null!;

    [Description("Tên hiển thị")]
    public string DisplayName { get; set; } = null!;

    [Description("Ảnh đại diện (StoredFiles.Id)")]
    public Guid? AvatarFileId { get; set; }

    [Description("Giới thiệu ngắn")]
    public string? Bio { get; set; }

    [Description("Ngày sinh")]
    public DateOnly? Birthday { get; set; }

    [Description("Tài khoản bị quản trị viên khoá (không đăng nhập được)")]
    public bool IsLocked { get; set; }

    [Description("Thời điểm đồng ý Điều khoản sử dụng & Chính sách quyền riêng tư")]
    public DateTimeOffset? TermsAcceptedAt { get; set; }

    [Description("Lần hoạt động gần nhất")]
    public DateTimeOffset? LastSeenAt { get; set; }
}
