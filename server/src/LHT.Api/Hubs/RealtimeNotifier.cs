using LHT.Application.Abstractions;
using Microsoft.AspNetCore.SignalR;

namespace LHT.Api.Hubs;

/// <summary>Cài đặt IRealtimeNotifier bằng IHubContext.</summary>
public class RealtimeNotifier(IHubContext<ChatHub> chat, IHubContext<NotificationHub> notify, PresenceTracker presence) : IRealtimeNotifier
{
    public Task ToUsersChatAsync(IEnumerable<Guid> userIds, string method, object payload, CancellationToken ct = default)
        => chat.Clients.Groups(userIds.Select(HubGroups.User).ToList()).SendAsync(method, payload, ct);

    public Task ToUsersAsync(IEnumerable<Guid> userIds, string method, object payload, CancellationToken ct = default)
    {
        var groups = userIds.Select(HubGroups.User).ToList();
        return groups.Count == 0 ? Task.CompletedTask : notify.Clients.Groups(groups).SendAsync(method, payload, ct);
    }

    public bool IsOnline(Guid userId) => presence.IsOnline(userId);
}
