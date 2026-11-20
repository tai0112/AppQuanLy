using System.Text.Json;

namespace LHT.Application.Features;

public sealed record SyncPullResponse(Dictionary<string, List<JsonElement>> Changes, DateTimeOffset ServerTime);
