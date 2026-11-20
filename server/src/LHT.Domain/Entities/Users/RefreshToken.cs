using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Refresh token để cấp lại access token")]
public class RefreshToken : OwnedEntity
{
    [Description("Giá trị token đã băm")]
    public string TokenHash { get; set; } = null!;

    [Description("Thời điểm hết hạn")]
    public DateTimeOffset ExpiresAt { get; set; }

    [Description("Thời điểm bị thu hồi")]
    public DateTimeOffset? RevokedAt { get; set; }

    [Description("Thiết bị sử dụng token")]
    public Guid? DeviceId { get; set; }
}
