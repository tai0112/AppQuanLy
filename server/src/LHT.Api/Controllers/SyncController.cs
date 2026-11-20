using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Sync;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

public class SyncController(SyncService sync) : BaseApiController
{
    [HttpPost("push")]
    public async Task<ActionResult<ApiResponse<SyncPushResponse>>> Push(SyncPushRequest req, CancellationToken ct)
        => OkResponse(await sync.PushAsync(CurrentUserId, req, ct));

    [HttpGet("pull")]
    public async Task<ActionResult<ApiResponse<SyncPullResponse>>> Pull([FromQuery] DateTimeOffset? since, CancellationToken ct)
        => OkResponse(await sync.PullAsync(CurrentUserId, since, ct));
}
