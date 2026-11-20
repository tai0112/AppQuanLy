using System.ComponentModel;

namespace LHT.Domain.Common;

/// <summary>Lớp gốc cho mọi bảng: khoá chính UUID do client sinh + thông tin thời gian + xoá mềm.</summary>
public abstract class BaseEntity : ISoftDelete
{
    /// <summary>Khoá chính. App sinh UUID v7 ngay trên máy để dùng được khi offline.</summary>
    [Description("Khoá chính (UUID v7 do app sinh)")]
    public Guid Id { get; set; }

    [Description("Thời điểm tạo (UTC)")]
    public DateTimeOffset CreatedAt { get; set; }

    [Description("Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ")]
    public DateTimeOffset UpdatedAt { get; set; }

    [Description("Thời điểm xoá mềm (UTC), NULL = chưa xoá")]
    public DateTimeOffset? DeletedAt { get; set; }
}
