namespace LHT.Application.Common;

/// <summary>Lỗi nghiệp vụ có mã lỗi và HTTP status, được middleware chuyển thành <see cref="ApiResponse{T}"/>.</summary>
public class AppException(string code, string message, int statusCode = 400, object? details = null)
    : Exception(message)
{
    public string Code { get; } = code;
    public int StatusCode { get; } = statusCode;
    public object? Details { get; } = details;

    public static AppException NotFound(string message = "Không tìm thấy dữ liệu")
        => new(ErrorCodes.NotFound, message, 404);

    public static AppException Forbidden(string message = "Bạn không có quyền thực hiện thao tác này")
        => new(ErrorCodes.Forbidden, message, 403);

    public static AppException Validation(object details, string message = "Dữ liệu không hợp lệ")
        => new(ErrorCodes.Validation, message, 422, details);
}
