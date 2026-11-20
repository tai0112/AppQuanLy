namespace LHT.Application.Features;

public sealed record SyncPushRequest(List<SyncChange> Changes);
