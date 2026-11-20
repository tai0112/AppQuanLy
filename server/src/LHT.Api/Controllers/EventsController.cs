using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[HasPermission(Perm.LichTrinh)]
public class EventsController(EventShareService share) : BaseApiController
{
    [HttpGet("invitations")]
    public async Task<ActionResult<ApiResponse<List<EventInvitationDto>>>> Invitations(CancellationToken ct)
        => OkResponse(await share.InvitationsAsync(CurrentUserId, ct));

    [HttpGet("{id:guid}/participants")]
    public async Task<ActionResult<ApiResponse<List<ParticipantDto>>>> Participants(Guid id, CancellationToken ct)
        => OkResponse(await share.ParticipantsAsync(CurrentUserId, id, ct));

    [HttpPost("{id:guid}/participants")]
    public async Task<ActionResult<ApiResponse<bool>>> Invite(Guid id, InviteRequest req, CancellationToken ct)
    {
        await share.InviteAsync(CurrentUserId, id, req, ct);
        return OkResponse(true);
    }

    [HttpDelete("{id:guid}/participants/{userId:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Remove(Guid id, Guid userId, CancellationToken ct)
    {
        await share.RemoveParticipantAsync(CurrentUserId, id, userId, ct);
        return OkResponse(true);
    }

    [HttpPost("{id:guid}/respond")]
    public async Task<ActionResult<ApiResponse<bool>>> Respond(Guid id, RespondRequest req, CancellationToken ct)
    {
        await share.RespondAsync(CurrentUserId, id, req.Accept, ct);
        return OkResponse(true);
    }
}
