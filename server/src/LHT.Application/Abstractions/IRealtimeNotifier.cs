namespace LHT.Application.Abstractions;

/// <summary>Gửi sự kiện realtime qua SignalR, không phụ thuộc trực tiếp vào SignalR.</summary>
public interface IRealtimeNotifier
{
    /// <summary>Gửi tới mọi kết nối ChatHub của các user.</summary>
    Task ToUsersChatAsync(IEnumerable<Guid> userIds, string method, object payload, CancellationToken ct = default);

    /// <summary>Gửi tới mọi kết nối NotificationHub của các user.</summary>
    Task ToUsersAsync(IEnumerable<Guid> userIds, string method, object payload, CancellationToken ct = default);

    /// <summary>User có đang online (có ít nhất 1 kết nối) không.</summary>
    bool IsOnline(Guid userId);
}
