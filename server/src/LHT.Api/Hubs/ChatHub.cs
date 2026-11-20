using LHT.Application.Features.Social;
using Microsoft.AspNetCore.SignalR;

namespace LHT.Api.Hubs;

public class ChatHub(ChatService chat) : AppHub
{
    public async Task JoinConversation(Guid conversationId)
    {
        await chat.EnsureMemberAsync(UserId, conversationId, Context.ConnectionAborted);
        await Groups.AddToGroupAsync(Context.ConnectionId, HubGroups.Conversation(conversationId));
    }

    public Task LeaveConversation(Guid conversationId)
        => Groups.RemoveFromGroupAsync(Context.ConnectionId, HubGroups.Conversation(conversationId));

    public Task Typing(Guid conversationId, bool isTyping)
        => Clients.OthersInGroup(HubGroups.Conversation(conversationId))
                  .SendAsync("Typing", new { conversationId, userId = UserId, isTyping });
}
