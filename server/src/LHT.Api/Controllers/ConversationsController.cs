using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[HasPermission(Perm.TinNhan)]
public class ConversationsController(ChatService chat) : BaseApiController
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<ConversationDto>>>> List(CancellationToken ct) => OkResponse(await chat.ListAsync(CurrentUserId, ct));

    [HttpPost("direct")]
    public async Task<ActionResult<ApiResponse<ConversationDto>>> Direct(CreateDirectRequest req, CancellationToken ct)
        => OkResponse(await chat.GetOrCreateDirectAsync(CurrentUserId, req.UserId, ct));

    [HttpPost("group")]
    public async Task<ActionResult<ApiResponse<ConversationDto>>> Group(CreateGroupRequest req, CancellationToken ct)
        => OkResponse(await chat.CreateGroupAsync(CurrentUserId, req, ct));

    [HttpGet("{id:guid}/messages")]
    public async Task<ActionResult<ApiResponse<CursorPage<MessageDto>>>> Messages(Guid id, [FromQuery] DateTimeOffset? before, [FromQuery] int limit = 30, CancellationToken ct = default)
        => OkResponse(await chat.MessagesAsync(CurrentUserId, id, before, limit, ct));

    [HttpPost("{id:guid}/messages")]
    public async Task<ActionResult<ApiResponse<MessageDto>>> Send(Guid id, SendMessageRequest req, CancellationToken ct)
        => OkResponse(await chat.SendAsync(CurrentUserId, id, req, ct));

    [HttpPost("{id:guid}/read")]
    public async Task<ActionResult<ApiResponse<bool>>> Read(Guid id, MarkReadRequest req, CancellationToken ct)
    {
        await chat.MarkReadAsync(CurrentUserId, id, req.MessageId, ct);
        return OkResponse(true);
    }
}
