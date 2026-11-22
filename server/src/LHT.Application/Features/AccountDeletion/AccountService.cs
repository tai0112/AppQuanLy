using System.Data.Common;
using System.Security.Cryptography;
using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace LHT.Application.Features.AccountDeletion;

/// <summary>
/// Xoá tài khoản ngay trong app (App Store Review Guideline 5.1.1(v)).
/// - Dữ liệu cá nhân (tài chính, lịch trình, chu kỳ, cài đặt, ảnh...) bị XOÁ VĨNH VIỄN khỏi CSDL, file ảnh bị xoá khỏi ổ đĩa.
/// - Bài viết của mình (kèm bình luận / cảm xúc trên đó) bị xoá; bình luận / tin nhắn mình gửi ở chỗ người khác bị xoá nội dung.
/// - Hồ sơ người dùng bị ẩn danh hoá + đánh dấu xoá (chỉ giữ Id để tin nhắn cũ của người khác không bị lỗi tham chiếu);
///   email / tên đăng nhập được giải phóng để có thể đăng ký lại.
/// </summary>
public class AccountService(IAppDbContext db, IFileStorage storage, TimeProvider clock, ILogger<AccountService> log)
{
    private static readonly PasswordHasher<User> Hasher = new();

    public async Task DeleteAsync(Guid me, string password, CancellationToken ct)
    {
        var user = await db.Set<User>().FirstOrDefaultAsync(u => u.Id == me, ct) ?? throw AppException.NotFound();
        if (string.IsNullOrEmpty(password) || Hasher.VerifyHashedPassword(user, user.PasswordHash, password) == PasswordVerificationResult.Failed)
            throw AppException.Validation(new { password = "Mật khẩu không đúng" });
        await PurgeAsync(me, ct);
    }

    /// <summary>Xoá vĩnh viễn dữ liệu + ẩn danh hoá hồ sơ (dùng cho người dùng tự xoá và quản trị viên xoá người dùng).</summary>
    public async Task PurgeAsync(Guid me, CancellationToken ct)
    {
        if (!await db.Set<User>().AnyAsync(u => u.Id == me, ct)) throw AppException.NotFound();
        var now = clock.GetUtcNow();
        var files = await db.Set<StoredFile>().IgnoreQueryFilters().Where(f => f.UserId == me)
            .Select(f => new { f.Id, f.Path, f.ThumbPath }).ToListAsync(ct);
        var fileIds = files.Select(f => f.Id).ToList();
        var myPosts = db.Set<Post>().IgnoreQueryFilters().Where(p => p.AuthorId == me).Select(p => p.Id);
        var myEvents = db.Set<Event>().IgnoreQueryFilters().Where(e => e.UserId == me).Select(e => e.Id);
        var myJars = db.Set<SavingsJar>().IgnoreQueryFilters().Where(j => j.UserId == me).Select(j => j.Id);
        var myPlans = db.Set<Plan>().IgnoreQueryFilters().Where(p => p.UserId == me).Select(p => p.Id);

        // Bài của người khác mà mình đã bình luận / thả cảm xúc → đếm lại số liệu sau khi xoá
        var touchedPosts = await db.Set<Comment>().IgnoreQueryFilters().Where(c => c.AuthorId == me).Select(c => c.PostId)
            .Union(db.Set<Reaction>().IgnoreQueryFilters().Where(r => r.ReactorUserId == me && r.TargetType == ReactionTarget.Post).Select(r => r.TargetId))
            .ToListAsync(ct);

        // SQL Server dùng chiến lược tự thử lại → giao dịch phải chạy trong execution strategy
        var strategy = db.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);

            // 1. Nội dung mình để lại ở chỗ người khác: xoá nội dung (giữ dòng để luồng hội thoại / trả lời không gãy)
            await db.Set<Message>().IgnoreQueryFilters().Where(m => m.SenderId == me)
                .ExecuteUpdateAsync(s => s.SetProperty(m => m.Content, (string?)null).SetProperty(m => m.DeletedAt, now).SetProperty(m => m.UpdatedAt, now), ct);
            await db.Set<Comment>().IgnoreQueryFilters().Where(c => c.AuthorId == me)
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.Content, "").SetProperty(c => c.DeletedAt, now).SetProperty(c => c.UpdatedAt, now), ct);
            await db.Set<Reaction>().IgnoreQueryFilters().Where(r => r.ReactorUserId == me).ExecuteDeleteAsync(ct);

            // 2. Bài viết của mình + mọi thứ gắn với nó
            var myComments = db.Set<Comment>().IgnoreQueryFilters().Where(c => myPosts.Contains(c.PostId)).Select(c => c.Id);
            await db.Set<Reaction>().IgnoreQueryFilters()
                .Where(r => (r.TargetType == ReactionTarget.Post && myPosts.Contains(r.TargetId)) || (r.TargetType == ReactionTarget.Comment && myComments.Contains(r.TargetId)))
                .ExecuteDeleteAsync(ct);
            await db.Set<Comment>().IgnoreQueryFilters().Where(c => c.ParentId != null && myComments.Contains(c.ParentId.Value)).ExecuteUpdateAsync(s => s.SetProperty(c => c.ParentId, (Guid?)null), ct);
            await db.Set<Comment>().IgnoreQueryFilters().Where(c => myPosts.Contains(c.PostId)).ExecuteDeleteAsync(ct);
            await db.Set<PostAudience>().IgnoreQueryFilters().Where(a => a.ViewerUserId == me || myPosts.Contains(a.PostId)).ExecuteDeleteAsync(ct);
            await db.Set<PostTag>().IgnoreQueryFilters().Where(t => t.TaggedUserId == me || myPosts.Contains(t.PostId)).ExecuteDeleteAsync(ct);
            await db.Set<Post>().IgnoreQueryFilters().Where(p => p.EventId != null && myEvents.Contains(p.EventId.Value)).ExecuteUpdateAsync(s => s.SetProperty(p => p.EventId, (Guid?)null), ct);
            await db.Set<Post>().IgnoreQueryFilters().Where(p => p.JarId != null && myJars.Contains(p.JarId.Value)).ExecuteUpdateAsync(s => s.SetProperty(p => p.JarId, (Guid?)null), ct);

            // 3. Quan hệ xã hội, quyền, báo cáo, thông báo do mình gây ra ở người khác
            await db.Set<Friendship>().IgnoreQueryFilters().Where(f => f.RequesterId == me || f.AddresseeId == me).ExecuteDeleteAsync(ct);
            await db.Set<ConversationMember>().IgnoreQueryFilters().Where(m => m.MemberUserId == me).ExecuteDeleteAsync(ct);
            await db.Set<Notification>().IgnoreQueryFilters().Where(n => n.ActorUserId == me).ExecuteDeleteAsync(ct);
            await db.Set<Report>().IgnoreQueryFilters().Where(r => r.ReporterId == me || r.TargetUserId == me).ExecuteDeleteAsync(ct);
            await db.Set<UserRole>().IgnoreQueryFilters().Where(r => r.MemberUserId == me).ExecuteDeleteAsync(ct);
            await db.Set<Conversation>().IgnoreQueryFilters().Where(c => c.AvatarFileId != null && fileIds.Contains(c.AvatarFileId.Value))
                .ExecuteUpdateAsync(s => s.SetProperty(c => c.AvatarFileId, (Guid?)null), ct);

            // 4. Lịch trình: người tham gia, hoạt động, ảnh trên lịch của mình hoặc do mình thêm vào lịch người khác
            await db.Set<EventParticipant>().IgnoreQueryFilters().Where(p => p.ParticipantUserId == me || myEvents.Contains(p.EventId)).ExecuteDeleteAsync(ct);
            await db.Set<EventItem>().IgnoreQueryFilters().Where(i => i.AddedByUserId == me || myEvents.Contains(i.EventId)).ExecuteDeleteAsync(ct);
            await db.Set<EventPhoto>().IgnoreQueryFilters().Where(p => p.AddedByUserId == me || myEvents.Contains(p.EventId) || fileIds.Contains(p.FileId)).ExecuteDeleteAsync(ct);
            await db.Set<PlanMember>().IgnoreQueryFilters().Where(m => m.MemberUserId == me || myPlans.Contains(m.PlanId)).ExecuteDeleteAsync(ct);
            await db.Set<User>().Where(u => u.Id == me).ExecuteUpdateAsync(s => s.SetProperty(u => u.AvatarFileId, (Guid?)null), ct);

            // 5. Toàn bộ dữ liệu sở hữu (tài chính, cá nhân, tệp...). Các bảng tham chiếu nhau nên xoá nhiều lượt:
            //    lượt nào vướng khoá ngoại thì để lượt sau, tới khi xoá sạch.
            var owned = new List<(string Name, Func<Task<int>> Delete)>
            {
                Owned<Attachment>(me, ct), Owned<Transaction>(me, ct), Owned<RecurringRule>(me, ct), Owned<JarTransaction>(me, ct), Owned<Budget>(me, ct),
                Owned<ElectricityBill>(me, ct), Owned<ElectricityTier>(me, ct), Owned<ElectricityMeter>(me, ct), Owned<ElectricityPriceTable>(me, ct),
                Owned<CycleLog>(me, ct), Owned<CyclePeriod>(me, ct), Owned<CycleSettings>(me, ct), Owned<LoveCounter>(me, ct), Owned<Reminder>(me, ct), Owned<AppSettings>(me, ct),
                ("Post", () => db.Set<Post>().IgnoreQueryFilters().Where(p => p.AuthorId == me).ExecuteDeleteAsync(ct)), Owned<Event>(me, ct), Owned<Plan>(me, ct), Owned<SavingsJar>(me, ct), Owned<Category>(me, ct),
                Owned<Account>(me, ct), Owned<ExchangeRate>(me, ct), Owned<Currency>(me, ct), Owned<Notification>(me, ct), Owned<Device>(me, ct),
                Owned<RefreshToken>(me, ct), Owned<StoredFile>(me, ct),
            };
            for (var pass = 0; owned.Count > 0; pass++)
            {
                var failed = new List<(string, Func<Task<int>>)>();
                Exception? last = null;
                foreach (var step in owned)
                {
                    try { await step.Delete(); }
                    catch (DbException ex) { failed.Add(step); last = ex; }
                }
                if (failed.Count == owned.Count || pass > 8)
                    throw new InvalidOperationException($"Không xoá được dữ liệu: {string.Join(", ", failed.Select(f => f.Item1))}", last);
                owned = failed;
            }

            // 6. Ẩn danh hoá hồ sơ + đánh dấu xoá (đăng nhập / làm mới phiên / đồng bộ đều bị từ chối từ đây)
            var anon = $"xoa_{me:N}";
            await db.Set<User>().Where(u => u.Id == me).ExecuteUpdateAsync(s => s
                .SetProperty(u => u.Email, $"{anon}@deleted.invalid")
                .SetProperty(u => u.Username, anon)
                .SetProperty(u => u.DisplayName, "Người dùng đã xoá")
                .SetProperty(u => u.PasswordHash, Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)))
                .SetProperty(u => u.Bio, (string?)null)
                .SetProperty(u => u.Birthday, (DateOnly?)null)
                .SetProperty(u => u.LastSeenAt, (DateTimeOffset?)null)
                .SetProperty(u => u.TermsAcceptedAt, (DateTimeOffset?)null)
                .SetProperty(u => u.UpdatedAt, now)
                .SetProperty(u => u.DeletedAt, now), ct);

            // Đếm lại bình luận / cảm xúc trên bài người khác
            await db.Set<Post>().Where(p => touchedPosts.Contains(p.Id)).ExecuteUpdateAsync(s => s
                .SetProperty(p => p.CommentCount, p => db.Set<Comment>().Count(c => c.PostId == p.Id))
                .SetProperty(p => p.ReactionCount, p => db.Set<Reaction>().Count(r => r.TargetType == ReactionTarget.Post && r.TargetId == p.Id)), ct);

            await tx.CommitAsync(ct);
        });

        // File ảnh trên ổ đĩa: xoá sau khi CSDL đã chốt
        foreach (var f in files)
        {
            foreach (var path in new[] { f.Path, f.ThumbPath })
            {
                if (string.IsNullOrEmpty(path)) continue;
                try { await storage.DeleteAsync(path, CancellationToken.None); }
                catch (Exception ex) { log.LogWarning(ex, "Không xoá được tệp {Path} của tài khoản đã xoá {User}", path, me); }
            }
        }
        log.LogInformation("Đã xoá tài khoản {User} ({Files} tệp)", me, files.Count);
    }

    private (string, Func<Task<int>>) Owned<T>(Guid me, CancellationToken ct) where T : OwnedEntity
        => (typeof(T).Name, () => db.Set<T>().IgnoreQueryFilters().Where(x => x.UserId == me).ExecuteDeleteAsync(ct));
}
