namespace LHT.Application.Features;

public sealed record UserProfile(Guid Id, string Email, string Username, string DisplayName, Guid? AvatarFileId, string? Bio, DateOnly? Birthday);
