using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

/// <summary>
/// Kiểm duyệt nội dung do người dùng tạo (App Store Review Guideline 1.2):
/// báo cáo vi phạm, chặn người dùng, quản trị viên xử lý báo cáo.
/// </summary>
public class ModerationService(IAppDbContext db, SocialLookup lookup, TimeProvider clock)
{
    // ================================================================ Báo cáo

    public async Task<Guid> ReportAsync(Guid me, CreateReportRequest req, CancellationToken ct)
    {
        var owner = req.TargetType switch
        {
            ReportTarget.Post => await db.Set<Post>().Where(p => p.Id == req.TargetId).Select(p => (Guid?)p.AuthorId).FirstOrDefaultAsync(ct),
            ReportTarget.Comment => await db.Set<Comment>().Where(c => c.Id == req.TargetId).Select(c => (Guid?)c.AuthorId).FirstOrDefaultAsync(ct),
            ReportTarget.Message => await db.Set<Message>()
                .Where(m => m.Id == req.TargetId && db.Set<ConversationMember>().Any(x => x.ConversationId == m.ConversationId && x.MemberUserId == me))
                .Select(m => (Guid?)m.SenderId).FirstOrDefaultAsync(ct),
            ReportTarget.User => await db.Set<User>().Where(u => u.Id == req.TargetId).Select(u => (Guid?)u.Id).FirstOrDefaultAsync(ct),
            _ => null,
        } ?? throw AppException.NotFound("Nội dung không còn tồn tại");
        if (owner == me) throw AppException.Validation(new { targetId = "Không thể báo cáo nội dung của chính mình" });

        var existing = await db.Set<Report>().Where(r => r.ReporterId == me && r.TargetType == req.TargetType && r.TargetId == req.TargetId && r.Status == ReportStatus.Open)
            .Select(r => (Guid?)r.Id).FirstOrDefaultAsync(ct);
        var id = existing ?? Guid.CreateVersion7();
        if (existing is null)
            db.Set<Report>().Add(new Report
            {
                Id = id, ReporterId = me, TargetType = req.TargetType, TargetId = req.TargetId, TargetUserId = owner, Reason = req.Reason,
                Note = string.IsNullOrWhiteSpace(req.Note) ? null : req.Note.Trim()[..Math.Min(req.Note.Trim().Length, 1000)],
            });
        await db.SaveChangesAsync(ct);
        if (req.Block) await BlockAsync(me, owner, ct);
        return id;
    }

    public async Task<List<ReportDto>> ListReportsAsync(ReportStatus? status, CancellationToken ct)
    {
        var q = db.Set<Report>().AsNoTracking();
        if (status is not null) q = q.Where(r => r.Status == status);
        var items = await q.OrderBy(r => r.Status).ThenByDescending(r => r.CreatedAt).Take(200).ToListAsync(ct);
        var users = await lookup.UsersAsync(items.Select(r => r.ReporterId).Concat(items.Where(r => r.TargetUserId != null).Select(r => r.TargetUserId!.Value)), ct);

        var postIds = items.Where(r => r.TargetType == ReportTarget.Post).Select(r => r.TargetId).ToList();
        var commentIds = items.Where(r => r.TargetType == ReportTarget.Comment).Select(r => r.TargetId).ToList();
        var messageIds = items.Where(r => r.TargetType == ReportTarget.Message).Select(r => r.TargetId).ToList();
        var preview = new Dictionary<Guid, string?>();
        foreach (var p in await db.Set<Post>().IgnoreQueryFilters().Where(p => postIds.Contains(p.Id)).Select(p => new { p.Id, p.Content }).ToListAsync(ct)) preview[p.Id] = p.Content;
        foreach (var c in await db.Set<Comment>().IgnoreQueryFilters().Where(c => commentIds.Contains(c.Id)).Select(c => new { c.Id, c.Content }).ToListAsync(ct)) preview[c.Id] = c.Content;
        foreach (var m in await db.Set<Message>().IgnoreQueryFilters().Where(m => messageIds.Contains(m.Id)).Select(m => new { m.Id, m.Content }).ToListAsync(ct)) preview[m.Id] = m.Content;

        UserSummary U(Guid id) => users.GetValueOrDefault(id) ?? new UserSummary(id, "?", "Người dùng đã xoá", null, false);
        return items.Select(r => new ReportDto(
            r.Id, U(r.ReporterId), r.TargetType, r.TargetId, r.TargetUserId is null ? null : U(r.TargetUserId.Value),
            r.Reason, r.Note, preview.GetValueOrDefault(r.TargetId), r.Status, r.CreatedAt, r.HandledAt)).ToList();
    }

    public Task<int> OpenCountAsync(CancellationToken ct) => db.Set<Report>().CountAsync(r => r.Status == ReportStatus.Open, ct);

    /// <summary>Xử lý báo cáo. Gỡ nội dung sẽ đóng luôn mọi báo cáo khác về cùng nội dung đó.</summary>
    public async Task ResolveAsync(Guid admin, Guid reportId, bool remove, CancellationToken ct)
    {
        var report = await db.Set<Report>().FirstOrDefaultAsync(r => r.Id == reportId, ct) ?? throw AppException.NotFound();
        var now = clock.GetUtcNow();
        if (remove)
        {
            switch (report.TargetType)
            {
                case ReportTarget.Post:
                    await db.Set<Post>().Where(p => p.Id == report.TargetId).ExecuteUpdateAsync(s => s.SetProperty(p => p.DeletedAt, now).SetProperty(p => p.UpdatedAt, now), ct);
                    break;
                case ReportTarget.Comment:
                    var postId = await db.Set<Comment>().Where(c => c.Id == report.TargetId).Select(c => (Guid?)c.PostId).FirstOrDefaultAsync(ct);
                    await db.Set<Comment>().Where(c => c.Id == report.TargetId).ExecuteUpdateAsync(s => s.SetProperty(c => c.DeletedAt, now).SetProperty(c => c.UpdatedAt, now), ct);
                    if (postId is not null)
                        await db.Set<Post>().Where(p => p.Id == postId).ExecuteUpdateAsync(s => s.SetProperty(p => p.CommentCount, p => db.Set<Comment>().Count(c => c.PostId == p.Id)), ct);
                    break;
                case ReportTarget.Message:
                    await db.Set<Message>().Where(m => m.Id == report.TargetId)
                        .ExecuteUpdateAsync(s => s.SetProperty(m => m.Content, (string?)null).SetProperty(m => m.DeletedAt, now).SetProperty(m => m.UpdatedAt, now), ct);
                    break;
            }
            await db.Set<Report>().Where(r => r.TargetType == report.TargetType && r.TargetId == report.TargetId && r.Status == ReportStatus.Open)
                .ExecuteUpdateAsync(s => s.SetProperty(r => r.Status, ReportStatus.Removed).SetProperty(r => r.HandledAt, now).SetProperty(r => r.HandledByUserId, admin).SetProperty(r => r.UpdatedAt, now), ct);
        }
        else
        {
            report.Status = ReportStatus.Dismissed;
            report.HandledAt = now;
            report.HandledByUserId = admin;
            await db.SaveChangesAsync(ct);
        }
    }

    // ================================================================ Chặn người dùng

    /// <summary>Chặn: không còn là bạn bè, không thấy bài / bình luận của nhau, không nhắn tin trực tiếp được, không tìm thấy nhau.</summary>
    public async Task BlockAsync(Guid me, Guid other, CancellationToken ct)
    {
        if (me == other) throw AppException.Validation(new { userId = "Không thể chặn chính mình" });
        if (!await db.Set<User>().AnyAsync(u => u.Id == other, ct)) throw AppException.NotFound("Không tìm thấy người dùng");
        var rows = await db.Set<Friendship>().Where(f => (f.RequesterId == me && f.AddresseeId == other) || (f.RequesterId == other && f.AddresseeId == me)).ToListAsync(ct);
        if (rows.Any(r => r.Status == FriendshipStatus.Blocked && r.RequesterId == me)) return;
        db.Set<Friendship>().RemoveRange(rows.Where(r => r.Status != FriendshipStatus.Blocked));
        db.Set<Friendship>().Add(new Friendship { Id = Guid.CreateVersion7(), RequesterId = me, AddresseeId = other, Status = FriendshipStatus.Blocked });
        await db.SaveChangesAsync(ct);
    }

    public async Task UnblockAsync(Guid me, Guid other, CancellationToken ct)
    {
        var rows = await db.Set<Friendship>().Where(f => f.Status == FriendshipStatus.Blocked && f.RequesterId == me && f.AddresseeId == other).ToListAsync(ct);
        db.Set<Friendship>().RemoveRange(rows);
        await db.SaveChangesAsync(ct);
    }

    public async Task<List<UserSummary>> BlockedAsync(Guid me, CancellationToken ct)
    {
        var ids = await db.Set<Friendship>().AsNoTracking().Where(f => f.Status == FriendshipStatus.Blocked && f.RequesterId == me).Select(f => f.AddresseeId).ToListAsync(ct);
        return (await lookup.UsersAsync(ids, ct)).Values.OrderBy(u => u.DisplayName).ToList();
    }
}
