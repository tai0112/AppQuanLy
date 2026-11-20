using LHT.Application.Common;
using Microsoft.EntityFrameworkCore;

namespace LHT.Api.Common;

/// <summary>Bắt mọi exception và trả về ApiResponse với mã lỗi thống nhất.</summary>
public class ExceptionMiddleware(RequestDelegate next, ILogger<ExceptionMiddleware> logger, IHostEnvironment env)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (AppException ex)
        {
            await Write(context, ex.StatusCode, ApiResponse<object>.Fail(ex.Code, ex.Message, ex.Details));
        }
        catch (DbUpdateConcurrencyException)
        {
            await Write(context, 409, ApiResponse<object>.Fail(ErrorCodes.Conflict, "Dữ liệu đã bị thay đổi ở nơi khác"));
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Lỗi không xử lý được: {Path}", context.Request.Path);
            var message = env.IsDevelopment() ? ex.Message : "Đã có lỗi xảy ra, vui lòng thử lại";
            await Write(context, 500, ApiResponse<object>.Fail(ErrorCodes.Internal, message));
        }
    }

    private static Task Write(HttpContext context, int status, ApiResponse<object> body)
    {
        if (context.Response.HasStarted) return Task.CompletedTask;
        context.Response.StatusCode = status;
        return context.Response.WriteAsJsonAsync(body);
    }
}
