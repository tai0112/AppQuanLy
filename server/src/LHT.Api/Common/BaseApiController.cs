using LHT.Application.Abstractions;
using LHT.Application.Common;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Common;

/// <summary>Controller gốc: route /api/v1/..., yêu cầu đăng nhập, trả về ApiResponse.</summary>
[ApiController]
[Authorize]
[Route("api/v1/[controller]")]
public abstract class BaseApiController : ControllerBase
{
    protected ICurrentUser CurrentUser => HttpContext.RequestServices.GetRequiredService<ICurrentUser>();
    protected Guid CurrentUserId => CurrentUser.RequireUserId();

    protected ActionResult<ApiResponse<T>> OkResponse<T>(T data) => Ok(ApiResponse<T>.Ok(data));
}
