using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record InviteRequest(List<Guid> UserIds, MemberRole Role = MemberRole.Editor);
