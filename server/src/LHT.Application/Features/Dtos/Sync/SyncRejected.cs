namespace LHT.Application.Features;

public sealed record SyncRejected(string Entity, Guid Id, string Reason);
