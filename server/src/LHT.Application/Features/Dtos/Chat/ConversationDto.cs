using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record ConversationDto(
    Guid Id, ConversationType Type, string? Name, Guid? AvatarFileId,
    IReadOnlyList<UserSummary> Members, MessageDto? LastMessage, int UnreadCount, DateTimeOffset? LastMessageAt);
