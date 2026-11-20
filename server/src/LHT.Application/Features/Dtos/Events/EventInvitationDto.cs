using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record EventInvitationDto(Guid EventId, string Title, DateTimeOffset StartAt, DateTimeOffset? EndAt, string? Location, UserSummary Owner, ParticipantStatus Status);
