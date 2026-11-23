using System.Reflection;
using System.Text.Json;
using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Common;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Sync;

/// <summary>
/// Đồng bộ offline-first cho dữ liệu cá nhân.
/// - Push: app gửi các bản ghi đã sửa (kể cả xoá mềm). Server upsert theo Id, ghi đè theo thứ tự đến (last-write-wins).
/// - Pull: app lấy mọi bản ghi có UpdatedAt &gt; mốc lần trước (gồm bản ghi đã xoá để app xoá theo).
/// Lịch trình được chia sẻ: người tham gia cũng pull được, người có quyền sửa cũng push được.
/// </summary>
public class SyncService(IAppDbContext db, TimeProvider clock, IRealtimeNotifier realtime)
{
    /// <summary>Danh sách bảng được đồng bộ, theo thứ tự phụ thuộc (bảng cha trước).</summary>
    public static readonly (string Name, Type Type, bool PullOnly)[] Entities =
    [
        ("appSettings", typeof(AppSettings), false),
        ("currencies", typeof(Currency), false),
        ("exchangeRates", typeof(ExchangeRate), false),
        ("accounts", typeof(Account), false),
        ("categories", typeof(Category), false),
        ("savingsJars", typeof(SavingsJar), false),
        ("plans", typeof(Plan), false),
        ("events", typeof(Event), false),
        ("eventParticipants", typeof(EventParticipant), true),
        ("eventPhotos", typeof(EventPhoto), false),
        ("eventItems", typeof(EventItem), false),
        ("recurringRules", typeof(RecurringRule), false),
        ("transactions", typeof(Transaction), false),
        ("jarTransactions", typeof(JarTransaction), false),
        ("budgets", typeof(Budget), false),
        ("attachments", typeof(Attachment), false),
        ("electricityPriceTables", typeof(ElectricityPriceTable), false),
        ("electricityTiers", typeof(ElectricityTier), false),
        ("electricityMeters", typeof(ElectricityMeter), false),
        ("electricityBills", typeof(ElectricityBill), false),
        ("loveCounters", typeof(LoveCounter), false),
        ("cycleSettings", typeof(CycleSettings), false),
        ("cyclePeriods", typeof(CyclePeriod), false),
        ("cycleLogs", typeof(CycleLog), false),
        ("reminders", typeof(Reminder), false),
    ];

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    private static readonly MethodInfo UpsertMethod = typeof(SyncService).GetMethod(nameof(UpsertAsync), BindingFlags.NonPublic | BindingFlags.Instance)!;
    private static readonly MethodInfo PullMethod = typeof(SyncService).GetMethod(nameof(PullEntityAsync), BindingFlags.NonPublic | BindingFlags.Instance)!;

    public async Task<SyncPushResponse> PushAsync(Guid me, SyncPushRequest req, CancellationToken ct)
    {
        // Tài khoản đã xoá (token cũ còn hạn) không được ghi lại dữ liệu
        if (!await db.Set<User>().AnyAsync(u => u.Id == me && !u.IsLocked, ct)) throw new AppException(ErrorCodes.Unauthorized, "Tài khoản không còn tồn tại hoặc đã bị khoá", 401);
        var index = Entities.Select((e, i) => (e.Name, i)).ToDictionary(x => x.Name, x => x.i);
        var rejected = new List<SyncRejected>();
        var valid = new List<(SyncChange Change, Guid Id)>();

        foreach (var c in req.Changes)
        {
            var id = c.Data.TryGetProperty("id", out var idEl) && idEl.TryGetGuid(out var g) ? g : Guid.Empty;
            if (!index.TryGetValue(c.Entity, out var i) || Entities[i].PullOnly)
                rejected.Add(new(c.Entity, id, "unknown_entity"));
            else if (id == Guid.Empty)
                rejected.Add(new(c.Entity, id, "missing_id"));
            else valid.Add((c, id));
        }

        // Bảng cha trước; danh mục cấp 1 trước danh mục con.
        var ordered = valid.OrderBy(v => index[v.Change.Entity])
            .ThenBy(v => v.Change.Data.TryGetProperty("parentId", out var p) && p.ValueKind != JsonValueKind.Null ? 1 : 0)
            .ToList();

        var accepted = new List<Guid>();
        var sharedEvents = new HashSet<Guid>();

        // Lượt 1: lưu cả lô. Nếu lỗi → lượt 2 lưu từng bản ghi để tách bản ghi lỗi.
        var batchRejected = new List<SyncRejected>();
        foreach (var (change, id) in ordered)
        {
            var reason = await RunUpsert(me, change, sharedEvents, ct);
            if (reason is null) accepted.Add(id); else batchRejected.Add(new(change.Entity, id, reason));
        }
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateException)
        {
            db.ChangeTracker.Clear();
            accepted.Clear();
            batchRejected.Clear();
            foreach (var (change, id) in ordered)
            {
                var reason = await RunUpsert(me, change, sharedEvents, ct);
                if (reason is null)
                {
                    try { await db.SaveChangesAsync(ct); accepted.Add(id); }
                    catch (DbUpdateException ex)
                    {
                        db.ChangeTracker.Clear();
                        var msg = ex.InnerException?.Message ?? ex.Message;
                        Console.WriteLine($"[Sync Rejected] Entity: {change.Entity}, Id: {id}, Error: {msg}");
                        reason = msg.Contains("duplicate key", StringComparison.OrdinalIgnoreCase) ? "conflict" : "invalid";
                    }
                }
                if (reason is not null) batchRejected.Add(new(change.Entity, id, reason));
            }
        }
        rejected.AddRange(batchRejected);

        // Báo cho những người cùng lịch trình chung để họ pull lại.
        if (sharedEvents.Count > 0)
        {
            var users = await db.Set<EventParticipant>().Where(p => sharedEvents.Contains(p.EventId) && p.Status != ParticipantStatus.Declined)
                .Select(p => p.ParticipantUserId)
                .Union(db.Set<Event>().IgnoreQueryFilters().Where(e => sharedEvents.Contains(e.Id)).Select(e => e.UserId))
                .ToListAsync(ct);
            await realtime.ToUsersAsync(users.Where(u => u != me), "SyncHint", new { reason = "events" }, ct);
        }

        return new SyncPushResponse(accepted, rejected, clock.GetUtcNow());
    }

    public async Task<SyncPullResponse> PullAsync(Guid me, DateTimeOffset? since, CancellationToken ct)
    {
        var serverTime = clock.GetUtcNow();
        var from = since ?? DateTimeOffset.MinValue;
        var result = new Dictionary<string, List<JsonElement>>();
        foreach (var (name, type, _) in Entities)
        {
            var task = (Task<List<JsonElement>>)PullMethod.MakeGenericMethod(type).Invoke(this, [me, from, ct])!;
            var items = await task;
            if (items.Count > 0) result[name] = items;
        }
        return new SyncPullResponse(result, serverTime);
    }

    private Task<string?> RunUpsert(Guid me, SyncChange change, HashSet<Guid> sharedEvents, CancellationToken ct)
    {
        var type = Entities.First(e => e.Name == change.Entity).Type;
        return (Task<string?>)UpsertMethod.MakeGenericMethod(type).Invoke(this, [me, change.Data, sharedEvents, ct])!;
    }

    // ---------------------------------------------------------------- Upsert

    private async Task<string?> UpsertAsync<T>(Guid me, JsonElement data, HashSet<Guid> sharedEvents, CancellationToken ct)
        where T : BaseEntity
    {
        T incoming;
        try { incoming = data.Deserialize<T>(Json)!; }
        catch (JsonException) { return "invalid"; }

        if (incoming is Transaction tx)
        {
            await ResolveTransactionReferencesAsync(me, tx, data, ct);
        }

        var existing = await db.Set<T>().IgnoreQueryFilters().FirstOrDefaultAsync(x => x.Id == incoming.Id, ct);

        // Kiểm tra quyền
        switch (incoming)
        {
            case Event:
                if (existing is Event ev && ev.UserId != me)
                {
                    var canEdit = await db.Set<EventParticipant>().AnyAsync(p => p.EventId == ev.Id && p.ParticipantUserId == me
                        && p.Status == ParticipantStatus.Accepted && p.Role != MemberRole.Viewer, ct);
                    if (!canEdit) return "forbidden";
                    sharedEvents.Add(ev.Id);
                }
                else if (existing is Event own && await db.Set<EventParticipant>().AnyAsync(p => p.EventId == own.Id, ct))
                    sharedEvents.Add(own.Id);
                break;

            case EventPhoto photo:
                if (!await CanAccessEventAsync(me, photo.EventId, ct)) return "forbidden";
                if (existing is EventPhoto old && old.AddedByUserId != me &&
                    !await db.Set<Event>().AnyAsync(e => e.Id == old.EventId && e.UserId == me, ct)) return "forbidden";
                photo.AddedByUserId = existing is EventPhoto o2 ? o2.AddedByUserId : me;
                sharedEvents.Add(photo.EventId);
                break;

            case EventItem item:
                // Hoạt động trong lịch trình: chủ lịch trình và người đã tham gia đều thêm/sửa được.
                if (!await CanAccessEventAsync(me, item.EventId, ct)) return "forbidden";
                if (existing is EventItem oldItem && oldItem.EventId != item.EventId) return "forbidden";
                item.AddedByUserId = existing is EventItem o3 ? o3.AddedByUserId : me;
                sharedEvents.Add(item.EventId);
                break;

            case OwnedEntity:
                if (existing is OwnedEntity ex && ex.UserId != me) return "forbidden";
                break;
        }

        if (existing is null)
        {
            if (incoming is OwnedEntity owned) owned.UserId = me;
            db.Set<T>().Add(incoming);
        }
        else
        {
            var owner = (existing as OwnedEntity)?.UserId;
            var created = existing.CreatedAt;
            db.Entry(existing).CurrentValues.SetValues(incoming);
            if (existing is OwnedEntity o && owner is not null) o.UserId = owner.Value;
            existing.CreatedAt = created;
            db.Entry(existing).State = EntityState.Modified;
        }
        return null;
    }

    // ---------------------------------------------------------------- Pull

    private async Task<List<JsonElement>> PullEntityAsync<T>(Guid me, DateTimeOffset since, CancellationToken ct) where T : BaseEntity
    {
        var set = db.Set<T>().IgnoreQueryFilters().AsNoTracking();
        var accessibleEvents = db.Set<Event>().IgnoreQueryFilters().Where(e => e.UserId == me).Select(e => e.Id)
            .Union(db.Set<EventParticipant>().Where(p => p.ParticipantUserId == me && p.Status != ParticipantStatus.Declined).Select(p => p.EventId));

        IQueryable<T> q = typeof(T) switch
        {
            var t when t == typeof(Event) => set.Where(x => accessibleEvents.Contains(x.Id)),
            var t when t == typeof(EventPhoto) => (IQueryable<T>)db.Set<EventPhoto>().IgnoreQueryFilters().AsNoTracking()
                .Where(p => accessibleEvents.Contains(p.EventId)),
            var t when t == typeof(EventItem) => (IQueryable<T>)db.Set<EventItem>().IgnoreQueryFilters().AsNoTracking()
                .Where(p => accessibleEvents.Contains(p.EventId)),
            var t when t == typeof(EventParticipant) => (IQueryable<T>)db.Set<EventParticipant>().IgnoreQueryFilters().AsNoTracking()
                .Where(p => accessibleEvents.Contains(p.EventId)),
            _ => set.Where(OwnedBy<T>(me)),
        };

        var list = await q.Where(x => x.UpdatedAt > since).OrderBy(x => x.UpdatedAt).ToListAsync(ct);
        return list.Select(x => JsonSerializer.SerializeToElement(x, Json)).ToList();
    }

    /// <summary>Biểu thức x =&gt; x.UserId == me cho kiểu T bất kỳ kế thừa OwnedEntity.</summary>
    private static System.Linq.Expressions.Expression<Func<T, bool>> OwnedBy<T>(Guid me)
    {
        var x = System.Linq.Expressions.Expression.Parameter(typeof(T), "x");
        var body = System.Linq.Expressions.Expression.Equal(
            System.Linq.Expressions.Expression.Property(x, nameof(OwnedEntity.UserId)),
            System.Linq.Expressions.Expression.Constant(me));
        return System.Linq.Expressions.Expression.Lambda<Func<T, bool>>(body, x);
    }

    /// Có quyền với lịch trình: là chủ (kể cả lịch trình MỚI nằm cùng lô đồng bộ, chưa lưu DB) hoặc người tham gia đã đồng ý.
    /// Lưu ý: app tạo lịch trình + hoạt động/ảnh lúc offline sẽ gửi chung một lô → phải xét cả bản ghi đang chờ lưu.
    private async Task<bool> CanAccessEventAsync(Guid me, Guid eventId, CancellationToken ct)
        => db.Set<Event>().Local.Any(e => e.Id == eventId && e.UserId == me)
           || await db.Set<Event>().AnyAsync(e => e.Id == eventId && e.UserId == me, ct)
           || await db.Set<EventParticipant>().AnyAsync(p => p.EventId == eventId && p.ParticipantUserId == me && p.Status == ParticipantStatus.Accepted, ct);

    /// <summary>
    /// Tự động tìm và ánh xạ lại Danh mục / Tài khoản khi ID không tồn tại trên DB.
    /// Tìm theo tên danh mục (nếu có), hoặc theo ghi chú, hoặc fallback về danh mục hợp lệ.
    /// </summary>
    private async Task ResolveTransactionReferencesAsync(Guid me, Transaction tx, JsonElement data, CancellationToken ct)
    {
        var categoryName = tx.CategoryName
            ?? (data.TryGetProperty("categoryName", out var cn) && cn.ValueKind == JsonValueKind.String ? cn.GetString() : null);
        var accountName = tx.AccountName
            ?? (data.TryGetProperty("accountName", out var an) && an.ValueKind == JsonValueKind.String ? an.GetString() : null);

        // 1. Ánh xạ Danh mục (CategoryId)
        if (tx.CategoryId.HasValue && tx.CategoryId.Value != Guid.Empty)
        {
            var catExists = await db.Set<Category>().AnyAsync(c => c.Id == tx.CategoryId.Value && c.UserId == me, ct);
            if (!catExists)
            {
                Category? matched = null;
                // Tìm theo tên danh mục
                if (!string.IsNullOrWhiteSpace(categoryName))
                {
                    var nameTrim = categoryName.Trim();
                    matched = await db.Set<Category>()
                        .FirstOrDefaultAsync(c => c.UserId == me && (byte)c.Type == (byte)tx.Type && c.Name.ToLower() == nameTrim.ToLower(), ct);
                }

                // Tìm theo ghi chú nếu ghi chú có nhắc đến tên danh mục
                if (matched == null && !string.IsNullOrWhiteSpace(tx.Note))
                {
                    var noteTrim = tx.Note.Trim();
                    matched = await db.Set<Category>()
                        .FirstOrDefaultAsync(c => c.UserId == me && (byte)c.Type == (byte)tx.Type && (c.Name.ToLower() == noteTrim.ToLower() || noteTrim.ToLower().Contains(c.Name.ToLower())), ct);
                }

                if (matched != null)
                {
                    tx.CategoryId = matched.Id;
                }
                else if (!string.IsNullOrWhiteSpace(categoryName))
                {
                    // Tự động tạo danh mục theo tên nếu chưa có
                    var newCat = new Category
                    {
                        Id = Guid.NewGuid(),
                        UserId = me,
                        Name = categoryName.Trim(),
                        Type = (CategoryType)tx.Type,
                        Icon = tx.Type == TransactionType.Income ? "payments" : "restaurant",
                        Color = tx.Type == TransactionType.Income ? "#30A46C" : "#F76B15",
                        CreatedAt = clock.GetUtcNow(),
                        UpdatedAt = clock.GetUtcNow()
                    };
                    db.Set<Category>().Add(newCat);
                    tx.CategoryId = newCat.Id;
                }
                else
                {
                    // Fallback về danh mục "Khác" hoặc danh mục đầu tiên cùng loại
                    var fallback = await db.Set<Category>()
                        .Where(c => c.UserId == me && (byte)c.Type == (byte)tx.Type && c.Name == "Khác")
                        .FirstOrDefaultAsync(ct)
                        ?? await db.Set<Category>()
                            .Where(c => c.UserId == me && (byte)c.Type == (byte)tx.Type && c.ParentId == null)
                            .OrderBy(c => c.SortOrder)
                            .FirstOrDefaultAsync(ct);
                    tx.CategoryId = fallback?.Id;
                }
            }
        }
        else if (tx.Type != TransactionType.Transfer)
        {
            // Giao dịch thu/chi chưa có CategoryId, thử tìm theo tên nếu có
            if (!string.IsNullOrWhiteSpace(categoryName))
            {
                var matched = await db.Set<Category>()
                    .FirstOrDefaultAsync(c => c.UserId == me && (byte)c.Type == (byte)tx.Type && c.Name.ToLower() == categoryName.Trim().ToLower(), ct);
                if (matched != null) tx.CategoryId = matched.Id;
            }
        }

        // 2. Ánh xạ Tài khoản nguồn (AccountId)
        if (tx.AccountId != Guid.Empty)
        {
            var accExists = await db.Set<Account>().AnyAsync(a => a.Id == tx.AccountId && a.UserId == me, ct);
            if (!accExists)
            {
                Account? matchedAcc = null;
                if (!string.IsNullOrWhiteSpace(accountName))
                {
                    var accTrim = accountName.Trim();
                    matchedAcc = await db.Set<Account>()
                        .FirstOrDefaultAsync(a => a.UserId == me && a.Name.ToLower() == accTrim.ToLower(), ct);
                }

                if (matchedAcc != null)
                {
                    tx.AccountId = matchedAcc.Id;
                }
                else
                {
                    // Fallback về tài khoản mặc định/đầu tiên của user
                    var fallbackAcc = await db.Set<Account>()
                        .Where(a => a.UserId == me)
                        .OrderBy(a => a.SortOrder)
                        .FirstOrDefaultAsync(ct);
                    if (fallbackAcc != null)
                    {
                        tx.AccountId = fallbackAcc.Id;
                        if (string.IsNullOrEmpty(tx.CurrencyCode)) tx.CurrencyCode = fallbackAcc.CurrencyCode;
                    }
                }
            }
        }

        // 3. Ánh xạ Tài khoản nhận (ToAccountId)
        if (tx.ToAccountId.HasValue && tx.ToAccountId.Value != Guid.Empty)
        {
            var toAccExists = await db.Set<Account>().AnyAsync(a => a.Id == tx.ToAccountId.Value && a.UserId == me, ct);
            if (!toAccExists)
            {
                tx.ToAccountId = null;
                tx.ToAmount = null;
            }
        }
    }
}
