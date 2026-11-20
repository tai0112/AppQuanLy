namespace LHT.Application.Features.Permissions;

public sealed record RoleDto(Guid Id, string Code, string Name, string? Description, bool IsActive, bool IsSystem, bool IsDefault, List<Guid> OperationIds, int UserCount);
