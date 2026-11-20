using System.Text.Json;
using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

/// <summary>Tạo thông báo: lưu DB + đẩy realtime (nếu online) hoặc push (nếu offline).</summary>
public class NotificationService(IAppDbContext db, IRealtimeNotifier realtime, IPushSender push, SocialLookup lookup)
{
    public async Task NotifyAsync(Guid userId, NotificationType type, Guid? actorId, string title, string? body,
        object? payload, CancellationToken ct)
    {
        if (actorId == userId) return;
        var n = new Notification
        {
            Id = Guid.CreateVersion7(), UserId = userId, Type = type, ActorUserId = actorId, Title = title, Body = body,
            PayloadJson = payload is null ? null : JsonSerializer.Serialize(payload, JsonSerializerOptions.Web),
        };
        db.Set<Notification>().Add(n);
        await db.SaveChangesAsync(ct);

        var actor = actorId is null ? null : await lookup.UserAsync(actorId.Value, ct);
        var dto = new NotificationDto(n.Id, n.Type, actor, n.Title, n.Body, n.PayloadJson, null, n.CreatedAt);
        await realtime.ToUsersAsync([userId], "Notification", dto, ct);
        if (!realtime.IsOnline(userId)) await push.SendAsync(userId, title, body, payload, ct);
    }

    public async Task<List<NotificationDto>> ListAsync(Guid userId, int limit, CancellationToken ct)
    {
        var items = await db.Set<Notification>().AsNoTracking().Where(n => n.UserId == userId)
            .OrderByDescending(n => n.CreatedAt).Take(Math.Clamp(limit, 1, 100)).ToListAsync(ct);
        var users = await lookup.UsersAsync(items.Where(i => i.ActorUserId != null).Select(i => i.ActorUserId!.Value), ct);
        return items.Select(n => new NotificationDto(n.Id, n.Type,
            n.ActorUserId is { } a ? users.GetValueOrDefault(a) : null, n.Title, n.Body, n.PayloadJson, n.ReadAt, n.CreatedAt)).ToList();
    }

    /// <summary>Số thông báo chưa đọc (huy hiệu trên menu "Thông báo").</summary>
    public Task<int> UnreadCountAsync(Guid userId, CancellationToken ct)
        => db.Set<Notification>().CountAsync(n => n.UserId == userId && n.ReadAt == null, ct);

    public async Task MarkAllReadAsync(Guid userId, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        await db.Set<Notification>().Where(n => n.UserId == userId && n.ReadAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, now).SetProperty(n => n.UpdatedAt, now), ct);
    }
}
