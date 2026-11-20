namespace LHT.Application.Features;

/// <summary>Kết quả tìm người dùng kèm quan hệ bạn bè hiện tại.</summary>
/// <param name="Relation">none / friend / outgoing (đã gửi lời mời) / incoming (được mời)</param>
public sealed record UserSearchItem(UserSummary User, string Relation, Guid? FriendshipId);
