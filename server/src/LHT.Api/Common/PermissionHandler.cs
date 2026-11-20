using LHT.Application.Features.Permissions;
using Microsoft.AspNetCore.Authorization;
using System.Security.Claims;

namespace LHT.Api.Common;

public class PermissionHandler(IServiceScopeFactory scopes) : AuthorizationHandler<PermissionRequirement>
{
    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext context, PermissionRequirement requirement)
    {
        if (!Guid.TryParse(context.User.FindFirstValue("sub"), out var userId)) return;
        using var scope = scopes.CreateScope();
        var perms = scope.ServiceProvider.GetRequiredService<IPermissionService>();
        if (await perms.HasAsync(userId, requirement.Code)) context.Succeed(requirement);
    }
}
