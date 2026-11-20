using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

public class FriendService(IAppDbContext db, SocialLookup lookup, NotificationService notifications)
{
    public async Task<List<UserSearchItem>> SearchAsync(Guid me, string q, CancellationToken ct)
    {
        q = q.Trim().ToLowerInvariant();
        if (q.Length < 2) return [];
        var users = await db.Set<User>().AsNoTracking()
            .Where(u => u.Id != me && (u.Username.Contains(q) || u.DisplayName.Contains(q) || u.Email == q))
            .OrderBy(u => u.Username).Take(30).Select(u => u.Id).ToListAsync(ct);
        var summaries = await lookup.UsersAsync(users, ct);
        var rels = await db.Set<Friendship>().AsNoTracking()
            .Where(f => (f.RequesterId == me && users.Contains(f.AddresseeId)) || (f.AddresseeId == me && users.Contains(f.RequesterId)))
            .ToListAsync(ct);

        return users.Select(id =>
        {
            var f = rels.FirstOrDefault(r => r.RequesterId == id || r.AddresseeId == id);
            var relation = f is null ? "none"
                : f.Status == FriendshipStatus.Accepted ? "friend"
                : f.Status == FriendshipStatus.Blocked ? "blocked"
                : f.RequesterId == me ? "outgoing" : "incoming";
            return new UserSearchItem(summaries[id], relation, f?.Id);
        }).Where(x => x.Relation != "blocked").ToList();
    }

    public async Task<List<UserSummary>> ListFriendsAsync(Guid me, CancellationToken ct)
    {
        var ids = await lookup.FriendIdsAsync(me, ct);
        return (await lookup.UsersAsync(ids, ct)).Values.OrderByDescending(u => u.IsOnline).ThenBy(u => u.DisplayName).ToList();
    }

    public async Task<List<FriendRequestItem>> ListRequestsAsync(Guid me, CancellationToken ct)
    {
        var reqs = await db.Set<Friendship>().AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Pending && (f.RequesterId == me || f.AddresseeId == me))
            .OrderByDescending(f => f.CreatedAt).ToListAsync(ct);
        var users = await lookup.UsersAsync(reqs.Select(r => r.RequesterId == me ? r.AddresseeId : r.RequesterId), ct);
        return reqs.Select(r =>
        {
            var other = r.RequesterId == me ? r.AddresseeId : r.RequesterId;
            return new FriendRequestItem(r.Id, users[other], r.AddresseeId == me, r.CreatedAt);
        }).ToList();
    }

    public async Task<Guid> SendRequestAsync(Guid me, Guid target, CancellationToken ct)
    {
        if (me == target) throw AppException.Validation(new { userId = "Không thể kết bạn với chính mình" });
        if (!await db.Set<User>().AnyAsync(u => u.Id == target, ct)) throw AppException.NotFound("Không tìm thấy người dùng");

        var existing = await db.Set<Friendship>().FirstOrDefaultAsync(f =>
            (f.RequesterId == me && f.AddresseeId == target) || (f.RequesterId == target && f.AddresseeId == me), ct);
        if (existing is not null)
        {
            if (existing.Status == FriendshipStatus.Accepted) throw new AppException(ErrorCodes.Conflict, "Hai bạn đã là bạn bè", 409);
            if (existing.Status == FriendshipStatus.Blocked) throw AppException.Forbidden();
            // Người kia đã mời mình trước → chấp nhận luôn.
            if (existing.AddresseeId == me) { await AcceptAsync(me, existing.Id, ct); return existing.Id; }
            return existing.Id;
        }

        var f = new Friendship { Id = Guid.CreateVersion7(), RequesterId = me, AddresseeId = target };
        db.Set<Friendship>().Add(f);
        await db.SaveChangesAsync(ct);
        var meUser = await lookup.UserAsync(me, ct);
        await notifications.NotifyAsync(target, NotificationType.FriendRequest, me, "Lời mời kết bạn",
            $"{meUser.DisplayName} muốn kết bạn với bạn", new { friendshipId = f.Id }, ct);
        return f.Id;
    }

    public async Task AcceptAsync(Guid me, Guid friendshipId, CancellationToken ct)
    {
        var f = await db.Set<Friendship>().FirstOrDefaultAsync(x => x.Id == friendshipId && x.AddresseeId == me, ct)
            ?? throw AppException.NotFound();
        if (f.Status != FriendshipStatus.Pending) return;
        f.Status = FriendshipStatus.Accepted;
        f.AcceptedAt = DateTimeOffset.UtcNow;
        await db.SaveChangesAsync(ct);
        var meUser = await lookup.UserAsync(me, ct);
        await notifications.NotifyAsync(f.RequesterId, NotificationType.FriendAccepted, me, "Đã chấp nhận kết bạn",
            $"{meUser.DisplayName} đã chấp nhận lời mời kết bạn", new { userId = me }, ct);
    }

    /// <summary>Từ chối / huỷ lời mời / huỷ kết bạn.</summary>
    public async Task RemoveAsync(Guid me, Guid friendshipId, CancellationToken ct)
    {
        var f = await db.Set<Friendship>().FirstOrDefaultAsync(x => x.Id == friendshipId && (x.AddresseeId == me || x.RequesterId == me), ct)
            ?? throw AppException.NotFound();
        db.Set<Friendship>().Remove(f);
        await db.SaveChangesAsync(ct);
    }

    public async Task UnfriendAsync(Guid me, Guid other, CancellationToken ct)
    {
        var f = await db.Set<Friendship>().FirstOrDefaultAsync(x =>
            (x.RequesterId == me && x.AddresseeId == other) || (x.RequesterId == other && x.AddresseeId == me), ct)
            ?? throw AppException.NotFound();
        db.Set<Friendship>().Remove(f);
        await db.SaveChangesAsync(ct);
    }

    // ================================================================ Cặp đôi (xác nhận hai chiều)

    private Task<Friendship?> FriendshipAsync(Guid me, Guid other, CancellationToken ct)
        => db.Set<Friendship>().FirstOrDefaultAsync(x => x.Status == FriendshipStatus.Accepted &&
            ((x.RequesterId == me && x.AddresseeId == other) || (x.RequesterId == other && x.AddresseeId == me)), ct);

    private Task<bool> HasPartnerAsync(Guid user, CancellationToken ct)
        => db.Set<Friendship>().AnyAsync(x => x.CoupleStatus == CoupleStatus.Accepted && (x.RequesterId == user || x.AddresseeId == user), ct);

    /// <summary>Người yêu hiện tại + lời mời đến / đã gửi.</summary>
    public async Task<CoupleState> GetCoupleAsync(Guid me, CancellationToken ct)
    {
        var rows = await db.Set<Friendship>().AsNoTracking()
            .Where(x => x.Status == FriendshipStatus.Accepted && x.CoupleStatus != null && (x.RequesterId == me || x.AddresseeId == me)).ToListAsync(ct);
        Guid Other(Friendship f) => f.RequesterId == me ? f.AddresseeId : f.RequesterId;
        var users = await lookup.UsersAsync(rows.Select(Other), ct);
        var accepted = rows.FirstOrDefault(r => r.CoupleStatus == CoupleStatus.Accepted);
        var incoming = rows.Where(r => r.CoupleStatus == CoupleStatus.Pending && r.CoupleRequesterId != me)
            .Select(r => new CoupleRequestItem(r.Id, users[Other(r)], r.UpdatedAt)).ToList();
        var outgoing = rows.Where(r => r.CoupleStatus == CoupleStatus.Pending && r.CoupleRequesterId == me)
            .Select(r => new CoupleRequestItem(r.Id, users[Other(r)], r.UpdatedAt)).FirstOrDefault();
        return new CoupleState(accepted is null ? null : users[Other(accepted)], accepted?.CoupleSince, incoming, outgoing);
    }

    /// <summary>Mời một người bạn làm người yêu. Nếu người đó đã mời mình trước → xác nhận luôn.</summary>
    public async Task RequestCoupleAsync(Guid me, Guid other, CancellationToken ct)
    {
        var f = await FriendshipAsync(me, other, ct) ?? throw new AppException(ErrorCodes.Conflict, "Hai bạn cần là bạn bè trước", 409);
        if (f.CoupleStatus == CoupleStatus.Accepted) return;
        if (f.CoupleStatus == CoupleStatus.Pending && f.CoupleRequesterId == other) { await AcceptCoupleAsync(me, other, ct); return; }
        if (await HasPartnerAsync(me, ct)) throw new AppException(ErrorCodes.Conflict, "Bạn đang có người yêu rồi", 409);
        if (await HasPartnerAsync(other, ct)) throw new AppException(ErrorCodes.Conflict, "Người này đang có người yêu", 409);

        // Chỉ giữ một lời mời đang chờ do mình gửi
        var mine = await db.Set<Friendship>().Where(x => x.CoupleStatus == CoupleStatus.Pending && x.CoupleRequesterId == me && x.Id != f.Id).ToListAsync(ct);
        foreach (var m in mine) { m.CoupleStatus = null; m.CoupleRequesterId = null; }

        f.CoupleStatus = CoupleStatus.Pending;
        f.CoupleRequesterId = me;
        await db.SaveChangesAsync(ct);
        var meUser = await lookup.UserAsync(me, ct);
        await notifications.NotifyAsync(other, NotificationType.CoupleRequest, me, "Lời mời làm người yêu ❤️",
            $"{meUser.DisplayName} muốn xác nhận hai bạn là người yêu", new { userId = me }, ct);
    }

    public async Task AcceptCoupleAsync(Guid me, Guid other, CancellationToken ct)
    {
        var f = await FriendshipAsync(me, other, ct) ?? throw AppException.NotFound();
        if (f.CoupleStatus != CoupleStatus.Pending || f.CoupleRequesterId != other) throw AppException.NotFound("Không có lời mời nào");
        if (await HasPartnerAsync(me, ct) || await HasPartnerAsync(other, ct))
            throw new AppException(ErrorCodes.Conflict, "Một trong hai người đang có người yêu", 409);

        f.CoupleStatus = CoupleStatus.Accepted;
        f.CoupleSince = DateTimeOffset.UtcNow;
        // Đã thành đôi → huỷ các lời mời đang chờ khác của cả hai
        var others = await db.Set<Friendship>().Where(x => x.Id != f.Id && x.CoupleStatus == CoupleStatus.Pending &&
            (x.RequesterId == me || x.AddresseeId == me || x.RequesterId == other || x.AddresseeId == other)).ToListAsync(ct);
        foreach (var o in others) { o.CoupleStatus = null; o.CoupleRequesterId = null; }
        await db.SaveChangesAsync(ct);
        var meUser = await lookup.UserAsync(me, ct);
        await notifications.NotifyAsync(other, NotificationType.CoupleAccepted, me, "Đã xác nhận người yêu ❤️",
            $"{meUser.DisplayName} đã đồng ý, hai bạn chính thức là một đôi", new { userId = me }, ct);
    }

    /// <summary>Từ chối / huỷ lời mời / kết thúc cặp đôi.</summary>
    public async Task EndCoupleAsync(Guid me, Guid other, CancellationToken ct)
    {
        var f = await FriendshipAsync(me, other, ct) ?? throw AppException.NotFound();
        if (f.CoupleStatus is null) return;
        var wasCouple = f.CoupleStatus == CoupleStatus.Accepted;
        var declined = f.CoupleStatus == CoupleStatus.Pending && f.CoupleRequesterId == other;
        f.CoupleStatus = null;
        f.CoupleRequesterId = null;
        f.CoupleSince = null;
        await db.SaveChangesAsync(ct);
        if (wasCouple || declined)
        {
            var meUser = await lookup.UserAsync(me, ct);
            await notifications.NotifyAsync(other, NotificationType.CoupleEnded, me,
                wasCouple ? "Đã huỷ liên kết người yêu" : "Lời mời người yêu bị từ chối",
                wasCouple ? $"{meUser.DisplayName} đã huỷ liên kết người yêu" : $"{meUser.DisplayName} đã từ chối lời mời", new { userId = me }, ct);
        }
    }
}
