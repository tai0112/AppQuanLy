using System.Collections.Concurrent;

namespace LHT.Api.Hubs;

/// <summary>Đếm số kết nối NotificationHub theo user để biết ai đang online.</summary>
public class PresenceTracker
{
    private readonly ConcurrentDictionary<Guid, int> _connections = new();

    /// <returns>true nếu đây là kết nối đầu tiên (vừa online)</returns>
    public bool Connected(Guid userId) => _connections.AddOrUpdate(userId, 1, (_, c) => c + 1) == 1;

    /// <returns>true nếu không còn kết nối nào (vừa offline)</returns>
    public bool Disconnected(Guid userId)
    {
        var left = _connections.AddOrUpdate(userId, 0, (_, c) => Math.Max(0, c - 1));
        if (left == 0) _connections.TryRemove(userId, out _);
        return left == 0;
    }

    public bool IsOnline(Guid userId) => _connections.ContainsKey(userId);
}
