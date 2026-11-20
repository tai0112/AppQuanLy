namespace LHT.Application.Features;

public sealed record UserSummary(Guid Id, string Username, string DisplayName, Guid? AvatarFileId, bool IsOnline);
