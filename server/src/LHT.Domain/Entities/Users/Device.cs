using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Thiết bị đăng nhập - nhận thông báo đẩy")]
public class Device : OwnedEntity
{
    [Description("Nền tảng: 1=iOS, 2=Android")]
    public DevicePlatform Platform { get; set; }

    [Description("FCM token để gửi push")]
    public string? FcmToken { get; set; }

    [Description("Tên thiết bị")]
    public string? Name { get; set; }

    [Description("Phiên bản app")]
    public string? AppVersion { get; set; }
}
