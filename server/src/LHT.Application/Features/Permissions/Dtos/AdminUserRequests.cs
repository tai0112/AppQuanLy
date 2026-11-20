namespace LHT.Application.Features.Permissions;

/// <param name="RoleIds">Vai trò gán ngay; rỗng = vai trò mặc định.</param>
public sealed record CreateUserRequest(string Email, string Username, string DisplayName, string Password, List<Guid>? RoleIds);

public sealed record ResetPasswordRequest(string NewPassword);

public sealed record SetLockedRequest(bool Locked);

public sealed record ChangePasswordRequest(string CurrentPassword, string NewPassword, string? RefreshToken);
