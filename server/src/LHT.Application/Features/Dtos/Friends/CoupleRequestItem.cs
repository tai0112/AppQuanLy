namespace LHT.Application.Features;

/// <summary>Lời mời làm người yêu (đến hoặc đã gửi).</summary>
public sealed record CoupleRequestItem(Guid FriendshipId, UserSummary User, DateTimeOffset CreatedAt);
