namespace LHT.Application.Features;

public sealed record SyncPushResponse(List<Guid> Accepted, List<SyncRejected> Rejected, DateTimeOffset ServerTime);
