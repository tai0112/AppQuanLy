namespace LHT.Application.Features.Permissions;

public sealed record AdminUserDto(
    Guid Id, string Email, string Username, string DisplayName, List<Guid> RoleIds, DateTimeOffset CreatedAt,
    bool IsLocked = false, DateTimeOffset? LastSeenAt = null);
