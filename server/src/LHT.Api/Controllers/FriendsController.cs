using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[HasPermission(Perm.BanBe)]
public class FriendsController(FriendService friends) : BaseApiController
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<UserSummary>>>> List(CancellationToken ct) => OkResponse(await friends.ListFriendsAsync(CurrentUserId, ct));

    [HttpGet("search")]
    public async Task<ActionResult<ApiResponse<List<UserSearchItem>>>> Search([FromQuery] string q, CancellationToken ct)
        => OkResponse(await friends.SearchAsync(CurrentUserId, q ?? "", ct));

    [HttpGet("requests")]
    public async Task<ActionResult<ApiResponse<List<FriendRequestItem>>>> Requests(CancellationToken ct)
        => OkResponse(await friends.ListRequestsAsync(CurrentUserId, ct));

    [HttpPost("requests")]
    public async Task<ActionResult<ApiResponse<Guid>>> Send(FriendRequestCreate req, CancellationToken ct)
        => OkResponse(await friends.SendRequestAsync(CurrentUserId, req.UserId, ct));

    [HttpPost("requests/{id:guid}/accept")]
    public async Task<ActionResult<ApiResponse<bool>>> Accept(Guid id, CancellationToken ct)
    {
        await friends.AcceptAsync(CurrentUserId, id, ct);
        return OkResponse(true);
    }

    /// <summary>Từ chối hoặc huỷ lời mời.</summary>
    [HttpDelete("requests/{id:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Decline(Guid id, CancellationToken ct)
    {
        await friends.RemoveAsync(CurrentUserId, id, ct);
        return OkResponse(true);
    }

    /// <summary>Người yêu (xác nhận hai chiều) + lời mời.</summary>
    [HttpGet("couple")]
    public async Task<ActionResult<ApiResponse<CoupleState>>> Couple(CancellationToken ct) => OkResponse(await friends.GetCoupleAsync(CurrentUserId, ct));

    [HttpPost("{userId:guid}/couple")]
    public async Task<ActionResult<ApiResponse<bool>>> RequestCouple(Guid userId, CancellationToken ct)
    {
        await friends.RequestCoupleAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }

    [HttpPost("{userId:guid}/couple/accept")]
    public async Task<ActionResult<ApiResponse<bool>>> AcceptCouple(Guid userId, CancellationToken ct)
    {
        await friends.AcceptCoupleAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }

    /// <summary>Từ chối, huỷ lời mời, hoặc huỷ liên kết người yêu.</summary>
    [HttpDelete("{userId:guid}/couple")]
    public async Task<ActionResult<ApiResponse<bool>>> EndCouple(Guid userId, CancellationToken ct)
    {
        await friends.EndCoupleAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }

    [HttpDelete("{userId:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Unfriend(Guid userId, CancellationToken ct)
    {
        await friends.UnfriendAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }
}
