namespace LHT.Application.Features;

/// <summary>Người yêu hiện tại (đã xác nhận hai chiều) + các lời mời.</summary>
public sealed record CoupleState(UserSummary? Partner, DateTimeOffset? Since, List<CoupleRequestItem> Incoming, CoupleRequestItem? Outgoing);
