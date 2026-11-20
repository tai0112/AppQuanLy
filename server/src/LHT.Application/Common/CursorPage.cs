namespace LHT.Application.Common;

/// <summary>Kết quả phân trang theo con trỏ (feed, chat).</summary>
public sealed record CursorPage<T>(IReadOnlyList<T> Items, string? NextCursor);
