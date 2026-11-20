using System.Text.Json;

namespace LHT.Application.Features;

/// <summary>Một thay đổi gửi từ app. <see cref="Entity"/> là tên bảng camelCase, vd "transactions".</summary>
public sealed record SyncChange(string Entity, JsonElement Data);
