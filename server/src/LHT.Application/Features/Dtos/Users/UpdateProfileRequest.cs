namespace LHT.Application.Features;

public sealed record UpdateProfileRequest(string DisplayName, string? Bio, Guid? AvatarFileId, DateOnly? Birthday);
