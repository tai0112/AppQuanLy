using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;

namespace LHT.Application.Features.Permissions;

/// <summary>Đọc quyền của người dùng từ DB, cache trong bộ nhớ 5 phút; đổi phân quyền thì xoá cache ngay.</summary>
public class PermissionService(IAppDbContext db, IMemoryCache cache) : IPermissionService
{
    private static long _version;

    public async Task<HashSet<string>> GetCodesAsync(Guid userId, CancellationToken ct = default)
    {
        var key = $"perm:{Interlocked.Read(ref _version)}:{userId}";
        if (cache.TryGetValue(key, out HashSet<string>? codes) && codes is not null) return codes;

        var roleIds = db.Set<UserRole>().Where(x => x.MemberUserId == userId).Select(x => x.RoleId);
        codes = (await (
                from ro in db.Set<RoleOperation>()
                join r in db.Set<Role>() on ro.RoleId equals r.Id
                join o in db.Set<Operation>() on ro.OperationId equals o.Id
                where roleIds.Contains(ro.RoleId) && r.IsActive
                select o.Code)
            .Distinct().ToListAsync(ct)).ToHashSet();

        cache.Set(key, codes, TimeSpan.FromMinutes(5));
        return codes;
    }

    public async Task<bool> HasAsync(Guid userId, string code, CancellationToken ct = default)
        => (await GetCodesAsync(userId, ct)).Contains(code);

    public async Task<MyPermissions> GetMineAsync(Guid userId, CancellationToken ct = default)
    {
        var codes = await GetCodesAsync(userId, ct);
        var roles = await (from ur in db.Set<UserRole>()
                           join r in db.Set<Role>() on ur.RoleId equals r.Id
                           where ur.MemberUserId == userId && r.IsActive
                           select r.Code).ToListAsync(ct);

        var modules = await db.Set<Module>().AsNoTracking().Where(m => m.IsShow).OrderBy(m => m.SortOrder).ToListAsync(ct);
        var ops = await db.Set<Operation>().AsNoTracking()
            .Where(o => o.IsShow && codes.Contains(o.Code)).OrderBy(o => o.SortOrder).ToListAsync(ct);

        var menu = modules
            .Select(m => new MenuModule(m.Id, m.Code, m.Name, m.Icon, m.SortOrder,
                ops.Where(o => o.ModuleId == m.Id)
                   .Select(o => new MenuOperation(o.Id, o.Code, o.Name, o.Route, o.Icon, o.SortOrder, o.ParentId)).ToList()))
            .Where(m => m.Operations.Count > 0).ToList();

        return new MyPermissions(roles, codes.OrderBy(c => c).ToList(), menu);
    }

    public void InvalidateAll() => Interlocked.Increment(ref _version);
}
