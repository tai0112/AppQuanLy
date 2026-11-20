using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record MessageDto(
    Guid Id, Guid ConversationId, Guid SenderId, MessageType Type, string? Content,
    Guid? ReplyToMessageId, DateTimeOffset ClientSentAt, DateTimeOffset ServerReceivedAt);
