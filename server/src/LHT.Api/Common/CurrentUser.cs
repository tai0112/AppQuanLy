using System.Security.Claims;
using LHT.Application.Abstractions;
using LHT.Application.Common;

namespace LHT.Api.Common;

/// <summary>Đọc UserId từ claim "sub" của JWT.</summary>
public class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public Guid? UserId
    {
        get
        {
            var user = accessor.HttpContext?.User;
            var value = user?.FindFirstValue("sub") ?? user?.FindFirstValue(ClaimTypes.NameIdentifier);
            return Guid.TryParse(value, out var id) ? id : null;
        }
    }

    public bool IsAuthenticated => UserId is not null;

    public Guid RequireUserId()
        => UserId ?? throw new AppException(ErrorCodes.Unauthorized, "Bạn cần đăng nhập", 401);
}
