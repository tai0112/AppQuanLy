namespace LHT.Application.Features;

public sealed record FriendRequestItem(Guid Id, UserSummary User, bool IsIncoming, DateTimeOffset CreatedAt);
