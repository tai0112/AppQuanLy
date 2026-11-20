namespace LHT.Application.Features.Permissions;

public sealed record SaveRoleRequest(string Code, string Name, string? Description, bool IsActive, bool IsDefault);
