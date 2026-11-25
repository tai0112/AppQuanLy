using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

/// <summary>Hàm dùng chung: tra cứu thông tin người dùng, danh sách bạn bè.</summary>
public class SocialLookup(IAppDbContext db, IRealtimeNotifier realtime)
{
    public async Task<Dictionary<Guid, UserSummary>> UsersAsync(IEnumerable<Guid> ids, CancellationToken ct)
    {
        var list = ids.Distinct().ToList();
        if (list.Count == 0) return [];
        return await db.Set<User>().AsNoTracking().Where(u => list.Contains(u.Id))
            .Select(u => new { u.Id, u.Username, u.DisplayName, u.AvatarFileId, u.LastSeenAt })
            .ToDictionaryAsync(u => u.Id, u => new UserSummary(u.Id, u.Username, u.DisplayName, u.AvatarFileId, realtime.IsOnline(u.Id), u.LastSeenAt), ct);
    }

    public async Task<UserSummary> UserAsync(Guid id, CancellationToken ct)
        => (await UsersAsync([id], ct)).GetValueOrDefault(id) ?? new UserSummary(id, "?", "Người dùng", null, false);

    public Task TouchLastSeenAsync(Guid userId, CancellationToken ct)
        => db.Set<User>().Where(u => u.Id == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.LastSeenAt, DateTimeOffset.UtcNow), ct);

    /// <summary>Người mình chặn + người chặn mình (ẩn nội dung hai chiều).</summary>
    public Task<List<Guid>> BlockedIdsAsync(Guid userId, CancellationToken ct)
        => db.Set<Friendship>().AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Blocked && (f.RequesterId == userId || f.AddresseeId == userId))
            .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
            .ToListAsync(ct);

    public Task<List<Guid>> FriendIdsAsync(Guid userId, CancellationToken ct)
        => db.Set<Friendship>().AsNoTracking()
            .Where(f => f.Status == FriendshipStatus.Accepted && (f.RequesterId == userId || f.AddresseeId == userId))
            .Select(f => f.RequesterId == userId ? f.AddresseeId : f.RequesterId)
            .ToListAsync(ct);

    public Task<bool> AreFriendsAsync(Guid a, Guid b, CancellationToken ct)
        => db.Set<Friendship>().AnyAsync(f => f.Status == FriendshipStatus.Accepted &&
            ((f.RequesterId == a && f.AddresseeId == b) || (f.RequesterId == b && f.AddresseeId == a)), ct);
}
