using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record SendMessageRequest(Guid Id, MessageType Type, string? Content, Guid? ReplyToMessageId, DateTimeOffset? ClientSentAt);
