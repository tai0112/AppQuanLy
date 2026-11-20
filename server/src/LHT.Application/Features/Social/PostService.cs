using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

public class PostService(IAppDbContext db, SocialLookup lookup, NotificationService notifications, IRealtimeNotifier realtime)
{
    /// <summary>Bảng tin: bài của mình + bài bạn bè mình được phép xem.</summary>
    public async Task<CursorPage<PostDto>> FeedAsync(Guid me, DateTimeOffset? before, int limit, CancellationToken ct)
    {
        var friends = await lookup.FriendIdsAsync(me, ct);
        var q = db.Set<Post>().AsNoTracking().Where(p =>
            !db.Set<Report>().Any(r => r.ReporterId == me && r.TargetType == ReportTarget.Post && r.TargetId == p.Id)).Where(p =>
            p.AuthorId == me ||
            (friends.Contains(p.AuthorId) && (p.Visibility == PostVisibility.Friends ||
                (p.Visibility == PostVisibility.Custom && db.Set<PostAudience>().Any(a => a.PostId == p.Id && a.ViewerUserId == me)))));
        return await PageAsync(me, q, before, limit, ct);
    }

    public async Task<CursorPage<PostDto>> ByUserAsync(Guid me, Guid userId, DateTimeOffset? before, int limit, CancellationToken ct)
    {
        var isFriend = userId == me || await lookup.AreFriendsAsync(me, userId, ct);
        var q = db.Set<Post>().AsNoTracking().Where(p => p.AuthorId == userId && (userId == me ||
            (isFriend && (p.Visibility == PostVisibility.Friends ||
                (p.Visibility == PostVisibility.Custom && db.Set<PostAudience>().Any(a => a.PostId == p.Id && a.ViewerUserId == me))))));
        return await PageAsync(me, q, before, limit, ct);
    }

    /// <summary>Một bài viết (mở từ thông báo); áp dụng cùng quyền xem như bảng tin.</summary>
    public async Task<PostDto> GetAsync(Guid me, Guid id, CancellationToken ct)
    {
        var p = await db.Set<Post>().AsNoTracking().FirstOrDefaultAsync(x => x.Id == id, ct)
            ?? throw AppException.NotFound("Bài viết không còn tồn tại");
        var ok = p.AuthorId == me || (await lookup.AreFriendsAsync(me, p.AuthorId, ct) && (p.Visibility == PostVisibility.Friends ||
            (p.Visibility == PostVisibility.Custom && await db.Set<PostAudience>().AnyAsync(a => a.PostId == id && a.ViewerUserId == me, ct))));
        if (!ok) throw AppException.NotFound("Bài viết không còn tồn tại");
        return (await MapAsync(me, [p], ct))[0];
    }

    public async Task<PostDto> CreateAsync(Guid me, CreatePostRequest req, CancellationToken ct)
    {
        if (req.Id == Guid.Empty) throw AppException.Validation(new { id = "Bắt buộc" });
        var existing = await db.Set<Post>().AsNoTracking().FirstOrDefaultAsync(p => p.Id == req.Id, ct);
        if (existing is not null) return (await MapAsync(me, [existing], ct))[0];
        if (string.IsNullOrWhiteSpace(req.Content) && (req.PhotoFileIds?.Count ?? 0) == 0)
            throw AppException.Validation(new { content = "Bài viết cần có nội dung hoặc ảnh" });

        var friends = await lookup.FriendIdsAsync(me, ct);
        var post = new Post
        {
            Id = req.Id, AuthorId = me, Content = req.Content?.Trim(), Visibility = req.Visibility,
            EventId = req.EventId, JarId = req.JarId, Location = req.Location, Feeling = req.Feeling,
        };
        db.Set<Post>().Add(post);

        var audience = req.Visibility == PostVisibility.Custom ? (req.AudienceIds ?? []).Where(friends.Contains).Distinct().ToList() : [];
        foreach (var a in audience)
            db.Set<PostAudience>().Add(new PostAudience { Id = Guid.CreateVersion7(), PostId = post.Id, ViewerUserId = a });
        var tags = (req.TagIds ?? []).Where(friends.Contains).Distinct().ToList();
        foreach (var t in tags)
            db.Set<PostTag>().Add(new PostTag { Id = Guid.CreateVersion7(), PostId = post.Id, TaggedUserId = t });

        var order = 0;
        var myFiles = await db.Set<StoredFile>().Where(f => f.UserId == me && (req.PhotoFileIds ?? new List<Guid>()).Contains(f.Id)).Select(f => f.Id).ToListAsync(ct);
        foreach (var fid in (req.PhotoFileIds ?? []).Where(myFiles.Contains))
            db.Set<Attachment>().Add(new Attachment
            {
                Id = Guid.CreateVersion7(), UserId = me, OwnerType = AttachmentOwnerType.Post, OwnerId = post.Id, FileId = fid, SortOrder = order++,
            });
        await db.SaveChangesAsync(ct);

        var dto = (await MapAsync(me, [post], ct))[0];
        var viewers = post.Visibility switch
        {
            PostVisibility.Friends => friends,
            PostVisibility.Custom => audience,
            _ => [],
        };
        await realtime.ToUsersAsync(viewers, "PostCreated", dto, ct);
        foreach (var t in tags)
            await notifications.NotifyAsync(t, NotificationType.Tagged, me, "Bạn được gắn thẻ",
                $"{dto.Author.DisplayName} đã gắn thẻ bạn trong một bài viết", new { postId = post.Id }, ct);
        return dto;
    }

    public async Task DeleteAsync(Guid me, Guid postId, CancellationToken ct)
    {
        var post = await db.Set<Post>().FirstOrDefaultAsync(p => p.Id == postId, ct) ?? throw AppException.NotFound();
        if (post.AuthorId != me) throw AppException.Forbidden();
        db.Set<Post>().Remove(post);
        await db.SaveChangesAsync(ct);
    }

    public async Task<PostDto> ReactAsync(Guid me, Guid postId, ReactionKind? kind, CancellationToken ct)
    {
        var post = await EnsureVisibleAsync(me, postId, ct);
        var r = await db.Set<Reaction>().FirstOrDefaultAsync(x => x.TargetType == ReactionTarget.Post && x.TargetId == postId && x.ReactorUserId == me, ct);
        var isNew = false;
        if (kind is null)
        {
            if (r is not null) { db.Set<Reaction>().Remove(r); post.ReactionCount = Math.Max(0, post.ReactionCount - 1); }
        }
        else if (r is null)
        {
            db.Set<Reaction>().Add(new Reaction { Id = Guid.CreateVersion7(), TargetType = ReactionTarget.Post, TargetId = postId, ReactorUserId = me, Kind = kind.Value });
            post.ReactionCount++;
            isNew = true;
        }
        else r.Kind = kind.Value;
        await db.SaveChangesAsync(ct);

        if (isNew)
        {
            var meUser = await lookup.UserAsync(me, ct);
            await notifications.NotifyAsync(post.AuthorId, NotificationType.NewReaction, me, "Cảm xúc mới",
                $"{meUser.DisplayName} đã bày tỏ cảm xúc về bài viết của bạn", new { postId }, ct);
        }
        return (await MapAsync(me, [post], ct))[0];
    }

    public async Task<List<CommentDto>> CommentsAsync(Guid me, Guid postId, CancellationToken ct)
    {
        await EnsureVisibleAsync(me, postId, ct);
        // Ẩn bình luận của người đã chặn / bị chặn và bình luận mình đã báo cáo
        var blocked = await lookup.BlockedIdsAsync(me, ct);
        var items = await db.Set<Comment>().AsNoTracking()
            .Where(c => c.PostId == postId && !blocked.Contains(c.AuthorId) &&
                !db.Set<Report>().Any(r => r.ReporterId == me && r.TargetType == ReportTarget.Comment && r.TargetId == c.Id))
            .OrderBy(c => c.CreatedAt).ToListAsync(ct);
        var users = await lookup.UsersAsync(items.Select(i => i.AuthorId), ct);
        return items.Select(c => new CommentDto(c.Id, c.PostId, users[c.AuthorId], c.ParentId, c.Content, c.CreatedAt)).ToList();
    }

    public async Task<CommentDto> AddCommentAsync(Guid me, Guid postId, CreateCommentRequest req, CancellationToken ct)
    {
        var post = await EnsureVisibleAsync(me, postId, ct);
        if (string.IsNullOrWhiteSpace(req.Content)) throw AppException.Validation(new { content = "Bình luận trống" });
        var c = new Comment { Id = req.Id ?? Guid.CreateVersion7(), PostId = postId, AuthorId = me, ParentId = req.ParentId, Content = req.Content.Trim() };
        db.Set<Comment>().Add(c);
        post.CommentCount++;
        await db.SaveChangesAsync(ct);
        var author = await lookup.UserAsync(me, ct);
        var dto = new CommentDto(c.Id, postId, author, c.ParentId, c.Content, c.CreatedAt);
        await notifications.NotifyAsync(post.AuthorId, NotificationType.NewComment, me, "Bình luận mới",
            $"{author.DisplayName}: {c.Content}", new { postId }, ct);
        return dto;
    }

    private async Task<Post> EnsureVisibleAsync(Guid me, Guid postId, CancellationToken ct)
    {
        var post = await db.Set<Post>().FirstOrDefaultAsync(p => p.Id == postId, ct) ?? throw AppException.NotFound();
        if (post.AuthorId == me) return post;
        var ok = post.Visibility switch
        {
            PostVisibility.Friends => await lookup.AreFriendsAsync(me, post.AuthorId, ct),
            PostVisibility.Custom => await db.Set<PostAudience>().AnyAsync(a => a.PostId == postId && a.ViewerUserId == me, ct),
            _ => false,
        };
        return ok ? post : throw AppException.NotFound();
    }

    private async Task<CursorPage<PostDto>> PageAsync(Guid me, IQueryable<Post> q, DateTimeOffset? before, int limit, CancellationToken ct)
    {
        limit = Math.Clamp(limit, 1, 50);
        if (before is not null) q = q.Where(p => p.CreatedAt < before);
        var posts = await q.OrderByDescending(p => p.CreatedAt).Take(limit).ToListAsync(ct);
        var next = posts.Count == limit ? posts[^1].CreatedAt.ToString("O") : null;
        return new CursorPage<PostDto>(await MapAsync(me, posts, ct), next);
    }

    private async Task<List<PostDto>> MapAsync(Guid me, List<Post> posts, CancellationToken ct)
    {
        var ids = posts.Select(p => p.Id).ToList();
        var photos = await db.Set<Attachment>().AsNoTracking()
            .Where(a => a.OwnerType == AttachmentOwnerType.Post && ids.Contains(a.OwnerId)).OrderBy(a => a.SortOrder).ToListAsync(ct);
        var tags = await db.Set<PostTag>().AsNoTracking().Where(t => ids.Contains(t.PostId)).ToListAsync(ct);
        var mine = await db.Set<Reaction>().AsNoTracking()
            .Where(r => r.TargetType == ReactionTarget.Post && ids.Contains(r.TargetId) && r.ReactorUserId == me)
            .ToDictionaryAsync(r => r.TargetId, r => r.Kind, ct);
        var eventIds = posts.Where(p => p.EventId != null).Select(p => p.EventId!.Value).ToList();
        var events = await db.Set<Event>().AsNoTracking().IgnoreQueryFilters().Where(e => eventIds.Contains(e.Id))
            .ToDictionaryAsync(e => e.Id, e => new EventBrief(e.Id, e.Title, e.StartAt, e.Location, e.CoverFileId), ct);
        var users = await lookup.UsersAsync(posts.Select(p => p.AuthorId).Concat(tags.Select(t => t.TaggedUserId)), ct);

        return posts.Select(p => new PostDto(p.Id, users[p.AuthorId], p.Content, p.Visibility,
            photos.Where(a => a.OwnerId == p.Id).Select(a => a.FileId).ToList(),
            tags.Where(t => t.PostId == p.Id).Select(t => users[t.TaggedUserId]).ToList(),
            p.EventId is { } e && events.TryGetValue(e, out var ev) ? ev : null,
            p.Location, p.Feeling, p.ReactionCount, p.CommentCount,
            mine.TryGetValue(p.Id, out var k) ? k : null, p.CreatedAt)).ToList();
    }
}
