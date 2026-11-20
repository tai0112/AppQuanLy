namespace LHT.Application.Abstractions;

/// <summary>Gửi thông báo đẩy (FCM → APNs) khi người dùng không mở app.</summary>
public interface IPushSender
{
    Task SendAsync(Guid userId, string title, string? body, object? data, CancellationToken ct = default);
}
