namespace LHT.Application.Features.Dtos.Admin;

public sealed record ApiLogDto(
    Guid Id,
    DateTimeOffset CreatedAt,
    Guid? UserId,
    string? Username,
    string Method,
    string Path,
    string? QueryString,
    int StatusCode,
    long DurationMs,
    string? IpAddress,
    string? UserAgent,
    string? RequestBody,
    string? ResponseBody,
    string? ErrorMessage);

public sealed record ApiLogFilterQuery(
    int Page = 1,
    int PageSize = 20,
    string? Search = null,
    string? Method = null,
    int? StatusCode = null,
    bool? OnlyErrors = null,
    DateTimeOffset? FromDate = null,
    DateTimeOffset? ToDate = null);

public sealed record ApiLogStatsDto(
    long TotalRequests,
    long ErrorRequests,
    double AvgDurationMs,
    long TodayRequests,
    long TodayErrors);

public sealed record PagedResult<T>(
    List<T> Items,
    long TotalCount,
    int Page,
    int PageSize,
    int TotalPages);

