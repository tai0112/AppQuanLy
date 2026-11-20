using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[AllowAnonymous]
public class AuthController(AuthService auth) : BaseApiController
{
    [HttpPost("register")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Register(RegisterRequest req, CancellationToken ct)
        => OkResponse(await auth.RegisterAsync(req, ct));

    [HttpPost("login")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Login(LoginRequest req, CancellationToken ct)
        => OkResponse(await auth.LoginAsync(req, ct));

    [HttpPost("refresh")]
    public async Task<ActionResult<ApiResponse<AuthResponse>>> Refresh(RefreshRequest req, CancellationToken ct)
        => OkResponse(await auth.RefreshAsync(req.RefreshToken, ct));

    [HttpPost("logout")]
    public async Task<ActionResult<ApiResponse<bool>>> Logout(RefreshRequest req, CancellationToken ct)
    {
        await auth.LogoutAsync(req.RefreshToken, ct);
        return OkResponse(true);
    }
}
