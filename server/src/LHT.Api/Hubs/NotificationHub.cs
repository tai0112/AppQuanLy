using LHT.Application.Features.Social;
using Microsoft.AspNetCore.SignalR;

namespace LHT.Api.Hubs;

public class NotificationHub(PresenceTracker presence, SocialLookup lookup) : AppHub
{
    public override async Task OnConnectedAsync()
    {
        await base.OnConnectedAsync();
        await lookup.TouchLastSeenAsync(UserId, CancellationToken.None);
        if (presence.Connected(UserId)) await BroadcastPresence(true);
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        await lookup.TouchLastSeenAsync(UserId, CancellationToken.None);
        if (presence.Disconnected(UserId)) await BroadcastPresence(false);
        await base.OnDisconnectedAsync(exception);
    }

    private async Task BroadcastPresence(bool online)
    {
        var friends = await lookup.FriendIdsAsync(UserId, CancellationToken.None);
        if (friends.Count == 0) return;
        await Clients.Groups(friends.Select(HubGroups.User).ToList())
            .SendAsync("PresenceChanged", new { userId = UserId, isOnline = online });
    }
}
