using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using LHT.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace LHT.Api.Services;

/// <summary>
/// Background service chạy mỗi giờ để tự động sinh giao dịch từ các quy tắc định kỳ đến hạn.
/// Dùng UUID v5 tất định theo (rule.Id, ngày) khớp hoàn toàn với Flutter client để chống trùng lặp tuyệt đối.
/// </summary>
public sealed class RecurringRuleWorker(IServiceScopeFactory scopeFactory, ILogger<RecurringRuleWorker> logger) : BackgroundService
{
    private static readonly Guid OidNamespace = Guid.Parse("6ba7b812-9dad-11d1-80b4-00c04fd430c8");

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Chờ ngắn lúc khởi động rồi chạy định kỳ mỗi 1 giờ
        await Task.Delay(TimeSpan.FromSeconds(15), stoppingToken);
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ProcessDueRulesAsync(stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                logger.LogError(ex, "Lỗi khi chạy RecurringRuleWorker");
            }
            await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }

    public async Task<int> ProcessDueRulesAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<IAppDbContext>();
        var now = DateTimeOffset.UtcNow;

        var rules = await db.Set<RecurringRule>()
            .Where(r => r.DeletedAt == null && r.IsActive && r.NextRunAt <= now)
            .ToListAsync(ct);

        if (rules.Count == 0) return 0;

        var created = 0;
        foreach (var rule in rules)
        {
            if (string.IsNullOrWhiteSpace(rule.RRule)) continue;

            JsonElement tpl;
            try
            {
                tpl = JsonSerializer.Deserialize<JsonElement>(rule.TemplateJson);
            }
            catch
            {
                continue;
            }

            if (!tpl.TryGetProperty("amount", out var amtEl) || !amtEl.TryGetDecimal(out var amount) || amount <= 0) continue;
            if (!tpl.TryGetProperty("accountId", out var accEl) || !Guid.TryParse(accEl.GetString(), out var accountId)) continue;

            var txType = tpl.TryGetProperty("type", out var typeEl) && typeEl.TryGetInt32(out var tInt)
                ? (TransactionType)tInt
                : TransactionType.Expense;
            var currency = tpl.TryGetProperty("currencyCode", out var curEl) && !string.IsNullOrWhiteSpace(curEl.GetString())
                ? curEl.GetString()!
                : "VND";
            Guid? toAccountId = tpl.TryGetProperty("toAccountId", out var toAccEl) && Guid.TryParse(toAccEl.GetString(), out var ta) ? ta : null;
            Guid? categoryId = tpl.TryGetProperty("categoryId", out var catEl) && Guid.TryParse(catEl.GetString(), out var cid) ? cid : null;
            var note = tpl.TryGetProperty("note", out var noteEl) ? noteEl.GetString() : null;

            var due = rule.NextRunAt;
            var guard = 0;
            while (due <= now && guard++ < 60)
            {
                var dateKey = due.ToString("yyyy-MM-dd");
                var txId = CreateUuidV5(OidNamespace, $"recurring:{rule.Id.ToString().ToLowerInvariant()}:{dateKey}");

                var exists = await db.Set<Transaction>().IgnoreQueryFilters().AnyAsync(x => x.Id == txId, ct);
                if (!exists)
                {
                    db.Set<Transaction>().Add(new Transaction
                    {
                        Id = txId,
                        UserId = rule.UserId,
                        Type = txType,
                        Amount = amount,
                        CurrencyCode = currency,
                        AccountId = accountId,
                        ToAccountId = txType == TransactionType.Transfer ? toAccountId : null,
                        CategoryId = txType != TransactionType.Transfer ? categoryId : null,
                        OccurredAt = due,
                        Note = string.IsNullOrWhiteSpace(note) ? rule.Name : note,
                        RecurringRuleId = rule.Id,
                        UpdatedAt = now,
                    });
                    created++;
                }

                due = NextOccurrence(rule.RRule, due);
            }

            rule.NextRunAt = due;
            rule.UpdatedAt = now;
        }

        if (created > 0 || rules.Count > 0)
        {
            await db.SaveChangesAsync(ct);
        }
        return created;
    }

    private static DateTimeOffset NextOccurrence(string rrule, DateTimeOffset from)
    {
        var parts = rrule.Split(';', StringSplitOptions.RemoveEmptyEntries)
            .Select(p => p.Split('=', 2))
            .Where(kv => kv.Length == 2)
            .ToDictionary(kv => kv[0].Trim().ToUpperInvariant(), kv => kv[1].Trim().ToUpperInvariant());

        var freq = parts.GetValueOrDefault("FREQ", "MONTHLY");
        var interval = parts.TryGetValue("INTERVAL", out var iv) && int.TryParse(iv, out var n) ? Math.Clamp(n, 1, 365) : 1;

        return freq switch
        {
            "DAILY" => from.AddDays(interval),
            "WEEKLY" => NextWeekly(from, parts.GetValueOrDefault("BYDAY"), interval),
            "MONTHLY" => AddMonthsClamped(from, interval),
            "YEARLY" => AddMonthsClamped(from, 12 * interval),
            _ => AddMonthsClamped(from, 1),
        };
    }

    private static DateTimeOffset NextWeekly(DateTimeOffset from, string? byDay, int interval)
    {
        if (string.IsNullOrWhiteSpace(byDay)) return from.AddDays(7 * interval);
        var map = new Dictionary<string, DayOfWeek>
        {
            ["MO"] = DayOfWeek.Monday,
            ["TU"] = DayOfWeek.Tuesday,
            ["WE"] = DayOfWeek.Wednesday,
            ["TH"] = DayOfWeek.Thursday,
            ["FR"] = DayOfWeek.Friday,
            ["SA"] = DayOfWeek.Saturday,
            ["SU"] = DayOfWeek.Sunday,
        };
        var days = byDay.Split(',').Select(s => map.GetValueOrDefault(s.Trim())).ToHashSet();
        if (days.Count == 0) return from.AddDays(7 * interval);

        static int IsoWeekday(DayOfWeek d) => d == DayOfWeek.Sunday ? 7 : (int)d;
        var fromIso = IsoWeekday(from.DayOfWeek);

        for (var offset = 1; offset <= 7; offset++)
        {
            var cand = from.AddDays(offset);
            var candIso = IsoWeekday(cand.DayOfWeek);
            if (candIso > fromIso && days.Contains(cand.DayOfWeek)) return cand;
            if (candIso <= fromIso)
            {
                var jump = cand.AddDays(7 * (interval - 1));
                for (var d = 0; d < 7; d++)
                {
                    var next = jump.AddDays(d);
                    if (days.Contains(next.DayOfWeek)) return next;
                }
            }
        }
        return from.AddDays(7 * interval);
    }

    private static DateTimeOffset AddMonthsClamped(DateTimeOffset from, int months)
    {
        var totalMonths = (from.Year * 12 + from.Month - 1) + months;
        var year = totalMonths / 12;
        var month = (totalMonths % 12) + 1;
        var day = Math.Min(from.Day, DateTime.DaysInMonth(year, month));
        return new DateTimeOffset(year, month, day, from.Hour, from.Minute, from.Second, from.Offset);
    }

    private static Guid CreateUuidV5(Guid namespaceId, string name)
    {
        var nsBytes = namespaceId.ToByteArray();
        SwapByteOrder(nsBytes);
        var nameBytes = Encoding.UTF8.GetBytes(name);
        var data = new byte[nsBytes.Length + nameBytes.Length];
        Buffer.BlockCopy(nsBytes, 0, data, 0, nsBytes.Length);
        Buffer.BlockCopy(nameBytes, 0, data, nsBytes.Length, nameBytes.Length);

        var hash = SHA1.HashData(data);
        var newGuid = new byte[16];
        Array.Copy(hash, 0, newGuid, 0, 16);
        newGuid[6] = (byte)((newGuid[6] & 0x0F) | (5 << 4));
        newGuid[8] = (byte)((newGuid[8] & 0x3F) | 0x80);
        SwapByteOrder(newGuid);
        return new Guid(newGuid);
    }

    private static void SwapByteOrder(byte[] guid)
    {
        (guid[0], guid[3]) = (guid[3], guid[0]);
        (guid[1], guid[2]) = (guid[2], guid[1]);
        (guid[4], guid[5]) = (guid[5], guid[4]);
        (guid[6], guid[7]) = (guid[7], guid[6]);
    }
}
