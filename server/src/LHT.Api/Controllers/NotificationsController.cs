using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Social;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

public class NotificationsController(NotificationService notifications) : BaseApiController
{
    [HttpGet]
    public async Task<ActionResult<ApiResponse<List<NotificationDto>>>> List([FromQuery] int limit = 50, CancellationToken ct = default)
        => OkResponse(await notifications.ListAsync(CurrentUserId, limit, ct));

    [HttpGet("unread-count")]
    public async Task<ActionResult<ApiResponse<int>>> UnreadCount(CancellationToken ct)
        => OkResponse(await notifications.UnreadCountAsync(CurrentUserId, ct));

    [HttpPost("read-all")]
    public async Task<ActionResult<ApiResponse<bool>>> ReadAll(CancellationToken ct)
    {
        await notifications.MarkAllReadAsync(CurrentUserId, ct);
        return OkResponse(true);
    }
}
