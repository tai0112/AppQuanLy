using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using LHT.Domain.Enums;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

/// <summary>Báo cáo vi phạm & chặn người dùng (App Store Guideline 1.2 — nội dung do người dùng tạo).</summary>
[Route("api/v1")]
public class ModerationController(ModerationService moderation) : BaseApiController
{
    [HttpPost("reports")]
    public async Task<ActionResult<ApiResponse<Guid>>> Report(CreateReportRequest req, CancellationToken ct)
        => OkResponse(await moderation.ReportAsync(CurrentUserId, req, ct));

    [HttpGet("blocks")]
    public async Task<ActionResult<ApiResponse<List<UserSummary>>>> Blocked(CancellationToken ct)
        => OkResponse(await moderation.BlockedAsync(CurrentUserId, ct));

    [HttpPost("blocks/{userId:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Block(Guid userId, CancellationToken ct)
    {
        await moderation.BlockAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }

    [HttpDelete("blocks/{userId:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Unblock(Guid userId, CancellationToken ct)
    {
        await moderation.UnblockAsync(CurrentUserId, userId, ct);
        return OkResponse(true);
    }

    // ---------------------------------------------------------------- Quản trị

    [HttpGet("admin/reports"), HasPermission(Perm.QuanTriBaoCao)]
    public async Task<ActionResult<ApiResponse<List<ReportDto>>>> Reports([FromQuery] ReportStatus? status, CancellationToken ct)
        => OkResponse(await moderation.ListReportsAsync(status, ct));

    [HttpGet("admin/reports/open-count"), HasPermission(Perm.QuanTriBaoCao)]
    public async Task<ActionResult<ApiResponse<int>>> OpenCount(CancellationToken ct) => OkResponse(await moderation.OpenCountAsync(ct));

    [HttpPost("admin/reports/{id:guid}/resolve"), HasPermission(Perm.QuanTriBaoCao)]
    public async Task<ActionResult<ApiResponse<bool>>> Resolve(Guid id, ResolveReportRequest req, CancellationToken ct)
    {
        await moderation.ResolveAsync(CurrentUserId, id, req.Remove, ct);
        return OkResponse(true);
    }
}
