using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record NotificationDto(Guid Id, NotificationType Type, UserSummary? Actor, string Title, string? Body, string? PayloadJson, DateTimeOffset? ReadAt, DateTimeOffset CreatedAt);
