using Microsoft.AspNetCore.Authorization;

namespace LHT.Api.Common;

public sealed record PermissionRequirement(string Code) : IAuthorizationRequirement;
