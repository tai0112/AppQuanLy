using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

/// <summary>Chia sẻ lịch trình: mời bạn bè, chấp nhận/từ chối. Dữ liệu lịch trình đi qua đồng bộ.</summary>
public class EventShareService(IAppDbContext db, SocialLookup lookup, NotificationService notifications, IRealtimeNotifier realtime)
{
    public async Task InviteAsync(Guid me, Guid eventId, InviteRequest req, CancellationToken ct)
    {
        var ev = await db.Set<Event>().FirstOrDefaultAsync(e => e.Id == eventId, ct)
            ?? throw AppException.NotFound("Lịch trình chưa được đồng bộ lên máy chủ");
        if (ev.UserId != me) throw AppException.Forbidden("Chỉ chủ lịch trình mới mời được");

        var friends = await lookup.FriendIdsAsync(me, ct);
        var targets = req.UserIds.Where(friends.Contains).Distinct().ToList();
        var existing = await db.Set<EventParticipant>().Where(p => p.EventId == eventId).ToListAsync(ct);
        foreach (var uid in targets)
        {
            var p = existing.FirstOrDefault(x => x.ParticipantUserId == uid);
            if (p is null)
                db.Set<EventParticipant>().Add(new EventParticipant
                {
                    Id = Guid.CreateVersion7(), EventId = eventId, ParticipantUserId = uid, Role = req.Role,
                });
            else { p.Status = ParticipantStatus.Invited; p.Role = req.Role; }
        }
        db.Entry(ev).State = EntityState.Modified; // cập nhật UpdatedAt để người được mời pull về
        await db.SaveChangesAsync(ct);

        var meUser = await lookup.UserAsync(me, ct);
        foreach (var uid in targets)
            await notifications.NotifyAsync(uid, NotificationType.EventInvite, me, "Lời mời tham gia lịch trình",
                $"{meUser.DisplayName} mời bạn tham gia \"{ev.Title}\"", new { eventId }, ct);
        await realtime.ToUsersAsync(targets, "SyncHint", new { reason = "events" }, ct);
    }

    public async Task RespondAsync(Guid me, Guid eventId, bool accept, CancellationToken ct)
    {
        var p = await db.Set<EventParticipant>().FirstOrDefaultAsync(x => x.EventId == eventId && x.ParticipantUserId == me, ct)
            ?? throw AppException.NotFound();
        p.Status = accept ? ParticipantStatus.Accepted : ParticipantStatus.Declined;
        var ev = await db.Set<Event>().IgnoreQueryFilters().FirstAsync(e => e.Id == eventId, ct);
        db.Entry(ev).State = EntityState.Modified;
        await db.SaveChangesAsync(ct);

        var meUser = await lookup.UserAsync(me, ct);
        await notifications.NotifyAsync(ev.UserId, NotificationType.EventChanged, me,
            accept ? "Đã nhận lời tham gia" : "Đã từ chối tham gia",
            $"{meUser.DisplayName} {(accept ? "sẽ tham gia" : "không tham gia")} \"{ev.Title}\"", new { eventId }, ct);
        await realtime.ToUsersAsync([ev.UserId], "SyncHint", new { reason = "events" }, ct);
    }

    public async Task RemoveParticipantAsync(Guid me, Guid eventId, Guid userId, CancellationToken ct)
    {
        var ev = await db.Set<Event>().FirstOrDefaultAsync(e => e.Id == eventId, ct) ?? throw AppException.NotFound();
        if (ev.UserId != me && userId != me) throw AppException.Forbidden();
        var p = await db.Set<EventParticipant>().FirstOrDefaultAsync(x => x.EventId == eventId && x.ParticipantUserId == userId, ct)
            ?? throw AppException.NotFound();
        db.Set<EventParticipant>().Remove(p);
        db.Entry(ev).State = EntityState.Modified;
        await db.SaveChangesAsync(ct);
        await realtime.ToUsersAsync([userId, ev.UserId], "SyncHint", new { reason = "events" }, ct);
    }

    public async Task<List<ParticipantDto>> ParticipantsAsync(Guid me, Guid eventId, CancellationToken ct)
    {
        var ev = await db.Set<Event>().AsNoTracking().FirstOrDefaultAsync(e => e.Id == eventId, ct) ?? throw AppException.NotFound();
        var ps = await db.Set<EventParticipant>().AsNoTracking().Where(p => p.EventId == eventId).ToListAsync(ct);
        if (ev.UserId != me && ps.All(p => p.ParticipantUserId != me)) throw AppException.Forbidden();
        var users = await lookup.UsersAsync(ps.Select(p => p.ParticipantUserId).Append(ev.UserId), ct);
        var list = new List<ParticipantDto> { new(ev.Id, users[ev.UserId], ParticipantStatus.Accepted, MemberRole.Owner) };
        list.AddRange(ps.Select(p => new ParticipantDto(p.Id, users[p.ParticipantUserId], p.Status, p.Role)));
        return list;
    }

    public async Task<List<EventInvitationDto>> InvitationsAsync(Guid me, CancellationToken ct)
    {
        var items = await (from p in db.Set<EventParticipant>()
                           join e in db.Set<Event>() on p.EventId equals e.Id
                           where p.ParticipantUserId == me && p.Status == ParticipantStatus.Invited
                           select new { e.Id, e.Title, e.StartAt, e.EndAt, e.Location, e.UserId, p.Status }).ToListAsync(ct);
        var users = await lookup.UsersAsync(items.Select(i => i.UserId), ct);
        return items.Select(i => new EventInvitationDto(i.Id, i.Title, i.StartAt, i.EndAt, i.Location, users[i.UserId], i.Status)).ToList();
    }
}
