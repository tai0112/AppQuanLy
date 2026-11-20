using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace LHT.Api.Hubs;

// Hai Hub SignalR (xác thực JWT qua ?access_token=):
//  - /hubs/chat          : tin nhắn mới, đang nhập, đã xem, nhóm mới
//  - /hubs/notifications : thông báo, bài viết mới, gợi ý đồng bộ (SyncHint), trạng thái online (PresenceChanged)
// Mỗi kết nối tự vào group "user:{id}" để server gửi riêng cho từng người.

[Authorize]
public abstract class AppHub : Hub
{
    protected Guid UserId => Guid.Parse(Context.UserIdentifier!);

    public override async Task OnConnectedAsync()
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.User(UserId));
        await base.OnConnectedAsync();
    }
}
