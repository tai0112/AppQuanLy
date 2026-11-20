using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Auth;
using LHT.Application.Features.Permissions;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[Route("api/v1/me")]
public class MeController(AuthService auth, IPermissionService permissions, LHT.Application.Features.AccountDeletion.AccountService account) : BaseApiController
{
    /// <summary>Đổi mật khẩu (giữ phiên hiện tại nếu gửi kèm refreshToken, các máy khác bị đăng xuất).</summary>
    [HttpPost("password")]
    public async Task<ActionResult<ApiResponse<bool>>> ChangePassword(LHT.Application.Features.Permissions.ChangePasswordRequest req, CancellationToken ct)
    {
        await auth.ChangePasswordAsync(CurrentUserId, req.CurrentPassword, req.NewPassword, req.RefreshToken, ct);
        return OkResponse(true);
    }

    /// <summary>Xoá tài khoản vĩnh viễn (yêu cầu nhập lại mật khẩu). App Store Guideline 5.1.1(v).</summary>
    [HttpPost("delete")]
    public async Task<ActionResult<ApiResponse<bool>>> Delete(DeleteAccountRequest req, CancellationToken ct)
    {
        await account.DeleteAsync(CurrentUserId, req.Password, ct);
        return OkResponse(true);
    }

    [HttpGet]
    public async Task<ActionResult<ApiResponse<UserProfile>>> Get(CancellationToken ct) => OkResponse(await auth.GetProfileAsync(CurrentUserId, ct));

    [HttpPut]
    public async Task<ActionResult<ApiResponse<UserProfile>>> Update(UpdateProfileRequest req, CancellationToken ct)
        => OkResponse(await auth.UpdateProfileAsync(CurrentUserId, req, ct));

    /// <summary>Quyền + menu động của người dùng hiện tại.</summary>
    [HttpGet("permissions")]
    public async Task<ActionResult<ApiResponse<MyPermissions>>> Permissions(CancellationToken ct)
        => OkResponse(await permissions.GetMineAsync(CurrentUserId, ct));
}
