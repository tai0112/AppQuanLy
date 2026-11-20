namespace LHT.Application.Features;

public sealed record CreateGroupRequest(string Name, List<Guid> MemberIds);
