using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record ParticipantDto(Guid Id, UserSummary User, ParticipantStatus Status, MemberRole Role);
