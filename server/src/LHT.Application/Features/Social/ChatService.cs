using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Social;

public class ChatService(IAppDbContext db, SocialLookup lookup, IRealtimeNotifier realtime, IPushSender push)
{
    public async Task<List<ConversationDto>> ListAsync(Guid me, CancellationToken ct)
    {
        var memberships = await db.Set<ConversationMember>().AsNoTracking().Where(m => m.MemberUserId == me).ToListAsync(ct);
        var convIds = memberships.Select(m => m.ConversationId).ToList();
        var convs = await db.Set<Conversation>().AsNoTracking().Where(c => convIds.Contains(c.Id))
            .OrderByDescending(c => c.LastMessageAt).ToListAsync(ct);
        var allMembers = await db.Set<ConversationMember>().AsNoTracking().Where(m => convIds.Contains(m.ConversationId)).ToListAsync(ct);
        var users = await lookup.UsersAsync(allMembers.Select(m => m.MemberUserId), ct);
        var lastIds = convs.Where(c => c.LastMessageId != null).Select(c => c.LastMessageId!.Value).ToList();
        var lasts = await db.Set<Message>().AsNoTracking().Where(m => lastIds.Contains(m.Id)).ToDictionaryAsync(m => m.Id, ct);

        var result = new List<ConversationDto>();
        foreach (var c in convs)
        {
            var mine = memberships.First(m => m.ConversationId == c.Id);
            DateTimeOffset? lastReadAt = null;
            if (mine.LastReadMessageId is { } lr)
                lastReadAt = await db.Set<Message>().Where(m => m.Id == lr).Select(m => (DateTimeOffset?)m.ServerReceivedAt).FirstOrDefaultAsync(ct);
            var unread = await db.Set<Message>().CountAsync(m => m.ConversationId == c.Id && m.SenderId != me &&
                (lastReadAt == null || m.ServerReceivedAt > lastReadAt), ct);
            result.Add(new ConversationDto(c.Id, c.Type, c.Name, c.AvatarFileId,
                allMembers.Where(m => m.ConversationId == c.Id).Select(m => users[m.MemberUserId]).ToList(),
                c.LastMessageId is { } li && lasts.TryGetValue(li, out var lm) ? ToDto(lm) : null,
                unread, c.LastMessageAt));
        }
        return result;
    }

    public async Task<ConversationDto> GetOrCreateDirectAsync(Guid me, Guid other, CancellationToken ct)
    {
        if (!await lookup.AreFriendsAsync(me, other, ct)) throw AppException.Forbidden("Chỉ nhắn tin được với bạn bè");
        var existing = await (from c in db.Set<Conversation>()
                              where c.Type == ConversationType.Direct
                                    && db.Set<ConversationMember>().Any(m => m.ConversationId == c.Id && m.MemberUserId == me)
                                    && db.Set<ConversationMember>().Any(m => m.ConversationId == c.Id && m.MemberUserId == other)
                              select c.Id).FirstOrDefaultAsync(ct);
        if (existing == Guid.Empty)
        {
            existing = Guid.CreateVersion7();
            db.Set<Conversation>().Add(new Conversation { Id = existing, Type = ConversationType.Direct, CreatedByUserId = me });
            db.Set<ConversationMember>().Add(new ConversationMember { Id = Guid.CreateVersion7(), ConversationId = existing, MemberUserId = me, Role = MemberRole.Owner });
            db.Set<ConversationMember>().Add(new ConversationMember { Id = Guid.CreateVersion7(), ConversationId = existing, MemberUserId = other });
            await db.SaveChangesAsync(ct);
        }
        return (await ListAsync(me, ct)).First(c => c.Id == existing);
    }

    public async Task<ConversationDto> CreateGroupAsync(Guid me, CreateGroupRequest req, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(req.Name)) throw AppException.Validation(new { name = "Bắt buộc" });
        var friends = await lookup.FriendIdsAsync(me, ct);
        var members = req.MemberIds.Where(friends.Contains).Distinct().ToList();
        if (members.Count == 0) throw AppException.Validation(new { memberIds = "Chọn ít nhất 1 người bạn" });

        var id = Guid.CreateVersion7();
        db.Set<Conversation>().Add(new Conversation { Id = id, Type = ConversationType.Group, Name = req.Name.Trim(), CreatedByUserId = me });
        db.Set<ConversationMember>().Add(new ConversationMember { Id = Guid.CreateVersion7(), ConversationId = id, MemberUserId = me, Role = MemberRole.Owner });
        foreach (var m in members)
            db.Set<ConversationMember>().Add(new ConversationMember { Id = Guid.CreateVersion7(), ConversationId = id, MemberUserId = m });
        await db.SaveChangesAsync(ct);
        var dto = (await ListAsync(me, ct)).First(c => c.Id == id);
        await realtime.ToUsersChatAsync(members, "ConversationCreated", dto, ct);
        return dto;
    }

    public async Task<CursorPage<MessageDto>> MessagesAsync(Guid me, Guid conversationId, DateTimeOffset? before, int limit, CancellationToken ct)
    {
        await EnsureMemberAsync(me, conversationId, ct);
        limit = Math.Clamp(limit, 1, 100);
        var q = db.Set<Message>().AsNoTracking().Where(m => m.ConversationId == conversationId);
        if (before is not null) q = q.Where(m => m.ServerReceivedAt < before);
        var items = await q.OrderByDescending(m => m.ServerReceivedAt).Take(limit).ToListAsync(ct);
        var next = items.Count == limit ? items[^1].ServerReceivedAt.ToString("O") : null;
        return new CursorPage<MessageDto>(items.Select(ToDto).ToList(), next);
    }

    /// <summary>Gửi tin nhắn. Idempotent theo Id do app sinh (gửi lại khi mất mạng không bị trùng).</summary>
    public async Task<MessageDto> SendAsync(Guid me, Guid conversationId, SendMessageRequest req, CancellationToken ct)
    {
        await EnsureMemberAsync(me, conversationId, ct);
        if (req.Id == Guid.Empty) throw AppException.Validation(new { id = "Bắt buộc" });
        if (string.IsNullOrWhiteSpace(req.Content)) throw AppException.Validation(new { content = "Tin nhắn trống" });
        // Hội thoại 1-1 với người đã chặn / bị chặn: không gửi được
        var blocked = await lookup.BlockedIdsAsync(me, ct);
        if (blocked.Count > 0 && await db.Set<Conversation>().AnyAsync(c => c.Id == conversationId && c.Type == ConversationType.Direct, ct) &&
            await db.Set<ConversationMember>().AnyAsync(m => m.ConversationId == conversationId && blocked.Contains(m.MemberUserId), ct))
            throw AppException.Forbidden("Không thể nhắn tin cho người này");

        var existing = await db.Set<Message>().AsNoTracking().FirstOrDefaultAsync(m => m.Id == req.Id, ct);
        if (existing is not null) return ToDto(existing);

        var now = DateTimeOffset.UtcNow;
        var msg = new Message
        {
            Id = req.Id, ConversationId = conversationId, SenderId = me, Type = req.Type, Content = req.Content,
            ReplyToMessageId = req.ReplyToMessageId, ClientSentAt = req.ClientSentAt ?? now, ServerReceivedAt = now,
        };
        db.Set<Message>().Add(msg);
        var conv = await db.Set<Conversation>().FirstAsync(c => c.Id == conversationId, ct);
        conv.LastMessageId = msg.Id;
        conv.LastMessageAt = now;
        var mine = await db.Set<ConversationMember>().FirstAsync(m => m.ConversationId == conversationId && m.MemberUserId == me, ct);
        mine.LastReadMessageId = msg.Id;
        await db.SaveChangesAsync(ct);

        var dto = ToDto(msg);
        var members = await MemberIdsAsync(conversationId, ct);
        await realtime.ToUsersChatAsync(members, "MessageReceived", dto, ct);

        var sender = await lookup.UserAsync(me, ct);
        var preview = msg.Type == MessageType.Image ? "[Hình ảnh]" : msg.Content;
        foreach (var uid in members.Where(u => u != me && !realtime.IsOnline(u)))
            await push.SendAsync(uid, conv.Name ?? sender.DisplayName, preview, new { conversationId }, ct);
        return dto;
    }

    public async Task MarkReadAsync(Guid me, Guid conversationId, Guid messageId, CancellationToken ct)
    {
        var mine = await db.Set<ConversationMember>().FirstOrDefaultAsync(m => m.ConversationId == conversationId && m.MemberUserId == me, ct)
            ?? throw AppException.Forbidden();
        mine.LastReadMessageId = messageId;
        mine.LastDeliveredMessageId = messageId;
        await db.SaveChangesAsync(ct);
        var members = await MemberIdsAsync(conversationId, ct);
        await realtime.ToUsersChatAsync(members.Where(u => u != me), "MessageRead",
            new { conversationId, userId = me, messageId }, ct);
    }

    public async Task<List<Guid>> MemberIdsAsync(Guid conversationId, CancellationToken ct)
        => await db.Set<ConversationMember>().Where(m => m.ConversationId == conversationId).Select(m => m.MemberUserId).ToListAsync(ct);

    public async Task EnsureMemberAsync(Guid me, Guid conversationId, CancellationToken ct)
    {
        if (!await db.Set<ConversationMember>().AnyAsync(m => m.ConversationId == conversationId && m.MemberUserId == me, ct))
            throw AppException.Forbidden("Bạn không thuộc cuộc trò chuyện này");
    }

    private static MessageDto ToDto(Message m)
        => new(m.Id, m.ConversationId, m.SenderId, m.Type, m.Content, m.ReplyToMessageId, m.ClientSentAt, m.ServerReceivedAt);
}
