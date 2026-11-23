using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;
using LHT.Domain.Entities;

namespace LHT.Api.Common;

public class ApiLoggingMiddleware(RequestDelegate next, IApiLogQueue queue, ILogger<ApiLoggingMiddleware> logger)
{
    private static readonly Regex SensitiveRegex = new(
        @"(""(?:password|matKhau|token|currentPassword|newPassword|refreshToken)""\s*:\s*"")([^""]*)("")",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public async Task InvokeAsync(HttpContext context)
    {
        var path = context.Request.Path.Value ?? "";

        // Chỉ ghi nhật ký các endpoint API (bỏ qua static files, health check)
        if (!path.StartsWith("/api", StringComparison.OrdinalIgnoreCase) || path.Equals("/health", StringComparison.OrdinalIgnoreCase))
        {
            await next(context);
            return;
        }

        var sw = Stopwatch.StartNew();
        var method = context.Request.Method;
        var queryString = context.Request.QueryString.HasValue ? context.Request.QueryString.Value : null;
        var ip = GetClientIp(context);
        var userAgent = context.Request.Headers.UserAgent.ToString();
        if (userAgent.Length > 500) userAgent = userAgent[..500];

        // Đọc Request Body nếu có (JSON)
        string? requestBody = null;
        if (HasJsonBody(context.Request))
        {
            try
            {
                context.Request.EnableBuffering();
                using var reader = new StreamReader(context.Request.Body, Encoding.UTF8, leaveOpen: true);
                var raw = await reader.ReadToEndAsync();
                context.Request.Body.Position = 0;

                if (!string.IsNullOrWhiteSpace(raw))
                {
                    requestBody = Sanitize(raw);
                    if (requestBody.Length > 10000) requestBody = requestBody[..10000] + "... [cắt ngắn]";
                }
            }
            catch (Exception ex)
            {
                logger.LogDebug(ex, "Không thể đọc request body cho {Path}", path);
            }
        }

        // Bắt Response Body (đặc biệt hữu ích khi có lỗi)
        var originalBodyStream = context.Response.Body;
        using var responseBodyStream = new MemoryStream();
        context.Response.Body = responseBodyStream;

        string? responseBody = null;
        string? errorMessage = null;

        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            errorMessage = ex.ToString();
            throw;
        }
        finally
        {
            sw.Stop();
            var statusCode = context.Response.StatusCode;

            try
            {
                responseBodyStream.Seek(0, SeekOrigin.Begin);
                var rawRes = await new StreamReader(responseBodyStream).ReadToEndAsync();
                responseBodyStream.Seek(0, SeekOrigin.Begin);
                await responseBodyStream.CopyToAsync(originalBodyStream);

                if (!string.IsNullOrWhiteSpace(rawRes) && (context.Response.ContentType?.Contains("json") == true || statusCode >= 400))
                {
                    responseBody = Sanitize(rawRes);
                    if (responseBody.Length > 4000) responseBody = responseBody[..4000] + "... [cắt ngắn]";
                }
            }
            catch (Exception ex)
            {
                logger.LogDebug(ex, "Không thể sao chép response body cho {Path}", path);
            }
            finally
            {
                context.Response.Body = originalBodyStream;
            }

            // Trích xuất thông tin người dùng sau khi Authentication Middleware đã chạy
            Guid? userId = null;
            string? username = null;
            if (context.User?.Identity?.IsAuthenticated == true)
            {
                var sub = context.User.FindFirst("sub")?.Value;
                if (Guid.TryParse(sub, out var g)) userId = g;
                username = context.User.FindFirst("name")?.Value ?? context.User.Identity.Name;
            }

            // Ghi console logger
            if (statusCode >= 500)
            {
                logger.LogError("[API] {Method} {Path} -> {StatusCode} ({DurationMs}ms) | User={User} IP={Ip} | Err={Error}",
                    method, path, statusCode, sw.ElapsedMilliseconds, username ?? "guest", ip, errorMessage ?? responseBody);
            }
            else if (statusCode >= 400)
            {
                logger.LogWarning("[API] {Method} {Path} -> {StatusCode} ({DurationMs}ms) | User={User} IP={Ip}",
                    method, path, statusCode, sw.ElapsedMilliseconds, username ?? "guest", ip);
            }
            else
            {
                logger.LogInformation("[API] {Method} {Path} -> {StatusCode} ({DurationMs}ms) | User={User} IP={Ip}",
                    method, path, statusCode, sw.ElapsedMilliseconds, username ?? "guest", ip);
            }

            // Đưa vào hàng đợi ghi database bất đồng bộ
            var log = new ApiLog
            {
                Id = Guid.CreateVersion7(),
                CreatedAt = DateTimeOffset.UtcNow,
                UpdatedAt = DateTimeOffset.UtcNow,
                UserId = userId,
                Username = username,
                Method = method,
                Path = path.Length > 300 ? path[..300] : path,
                QueryString = queryString != null && queryString.Length > 1000 ? queryString[..1000] : queryString,
                StatusCode = statusCode,
                DurationMs = sw.ElapsedMilliseconds,
                IpAddress = ip,
                UserAgent = userAgent,
                RequestBody = requestBody,
                ResponseBody = responseBody,
                ErrorMessage = errorMessage,
            };

            queue.Queue(log);
        }
    }

    private static bool HasJsonBody(HttpRequest req)
    {
        if (req.ContentLength is 0) return false;
        var method = req.Method;
        if (method != "POST" && method != "PUT" && method != "PATCH" && method != "DELETE") return false;
        var ct = req.ContentType;
        return ct != null && ct.Contains("application/json", StringComparison.OrdinalIgnoreCase);
    }

    private static string Sanitize(string json)
    {
        return SensitiveRegex.Replace(json, "$1***$3");
    }

    private static string? GetClientIp(HttpContext ctx)
    {
        var h = ctx.Request.Headers;
        if (h.TryGetValue("CF-Connecting-IP", out var cfIp) && !string.IsNullOrWhiteSpace(cfIp))
            return cfIp.ToString().Trim();

        if (h.TryGetValue("X-Forwarded-For", out var xff) && !string.IsNullOrWhiteSpace(xff))
        {
            var first = xff.ToString().Split(',')[0].Trim();
            if (!string.IsNullOrWhiteSpace(first)) return first;
        }

        return ctx.Connection.RemoteIpAddress?.ToString();
    }
}

