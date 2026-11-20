namespace LHT.Application.Common;

/// <summary>Danh sách mã lỗi dùng chung giữa server và app.</summary>
public static class ErrorCodes
{
    public const string Internal = "INTERNAL_ERROR";
    public const string Validation = "VALIDATION_ERROR";
    public const string NotFound = "NOT_FOUND";
    public const string Unauthorized = "UNAUTHORIZED";
    public const string Forbidden = "FORBIDDEN";
    public const string Conflict = "CONFLICT";
}
