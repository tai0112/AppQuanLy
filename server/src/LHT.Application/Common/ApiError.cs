namespace LHT.Application.Common;

/// <summary>Thông tin lỗi. <see cref="Code"/> cố định để app dịch/hiển thị.</summary>
public sealed record ApiError(string Code, string Message, object? Details = null);
