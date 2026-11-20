using LHT.Application.Abstractions;
using Microsoft.Extensions.Logging;

namespace LHT.Infrastructure.Services;

/// <summary>
/// Push tạm thời chỉ ghi log. Khi có Firebase project: thay bằng FcmPushSender (FirebaseAdmin) gửi tới Devices.FcmToken.
/// </summary>
public class LoggingPushSender(ILogger<LoggingPushSender> logger) : IPushSender
{
    public Task SendAsync(Guid userId, string title, string? body, object? data, CancellationToken ct = default)
    {
        logger.LogInformation("[PUSH] → {UserId}: {Title} - {Body}", userId, title, body);
        return Task.CompletedTask;
    }
}
