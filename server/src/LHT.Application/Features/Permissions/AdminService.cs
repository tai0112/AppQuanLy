using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Permissions;

/// <summary>Quản trị vai trò, chức năng, gán quyền.</summary>
public class AdminService(IAppDbContext db, IPermissionService permissions, LHT.Application.Features.Auth.AuthService auth, LHT.Application.Features.AccountDeletion.AccountService accounts)
{
    // ----- Vai trò -----
    public async Task<List<RoleDto>> GetRolesAsync(CancellationToken ct)
    {
        var roles = await db.Set<Role>().AsNoTracking().OrderBy(r => r.Code).ToListAsync(ct);
        var ro = await db.Set<RoleOperation>().AsNoTracking().ToListAsync(ct);
        var ur = await db.Set<UserRole>().AsNoTracking().GroupBy(x => x.RoleId)
            .Select(g => new { g.Key, Count = g.Count() }).ToListAsync(ct);
        return roles.Select(r => new RoleDto(r.Id, r.Code, r.Name, r.Description, r.IsActive, r.IsSystem, r.IsDefault,
            ro.Where(x => x.RoleId == r.Id).Select(x => x.OperationId).ToList(),
            ur.FirstOrDefault(x => x.Key == r.Id)?.Count ?? 0)).ToList();
    }

    public async Task<Guid> SaveRoleAsync(Guid? id, SaveRoleRequest req, CancellationToken ct)
    {
        var code = req.Code.Trim().ToUpperInvariant();
        if (string.IsNullOrWhiteSpace(code) || string.IsNullOrWhiteSpace(req.Name))
            throw AppException.Validation(new { code = "Bắt buộc", name = "Bắt buộc" });
        if (await db.Set<Role>().AnyAsync(r => r.Code == code && r.Id != id, ct))
            throw new AppException(ErrorCodes.Conflict, "Mã vai trò đã tồn tại", 409);

        var role = id is null ? null : await db.Set<Role>().FirstOrDefaultAsync(r => r.Id == id, ct);
        if (id is not null && role is null) throw AppException.NotFound();
        if (role is null)
        {
            role = new Role { Id = Guid.CreateVersion7() };
            db.Set<Role>().Add(role);
        }
        if (!role.IsSystem) role.Code = code;
        role.Name = req.Name.Trim();
        role.Description = req.Description;
        role.IsActive = role.IsSystem || req.IsActive;
        role.IsDefault = req.IsDefault;
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
        return role.Id;
    }

    public async Task DeleteRoleAsync(Guid id, CancellationToken ct)
    {
        var role = await db.Set<Role>().FirstOrDefaultAsync(r => r.Id == id, ct) ?? throw AppException.NotFound();
        if (role.IsSystem) throw new AppException(ErrorCodes.Forbidden, "Không thể xoá vai trò hệ thống", 403);
        db.Set<RoleOperation>().RemoveRange(db.Set<RoleOperation>().Where(x => x.RoleId == id));
        db.Set<UserRole>().RemoveRange(db.Set<UserRole>().Where(x => x.RoleId == id));
        db.Set<Role>().Remove(role);
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
    }

    /// <summary>Gán lại toàn bộ chức năng cho vai trò.</summary>
    public async Task SetRoleOperationsAsync(Guid roleId, List<Guid> operationIds, CancellationToken ct)
    {
        var role = await db.Set<Role>().FirstOrDefaultAsync(r => r.Id == roleId, ct) ?? throw AppException.NotFound();
        if (role.Code == Perm.RoleAdmin)
        {
            // Không để ADMIN tự mất quyền quản trị phân quyền.
            var adminOp = await db.Set<Operation>().Where(o => o.Code == Perm.QuanTriVaiTro).Select(o => o.Id).FirstAsync(ct);
            if (!operationIds.Contains(adminOp)) operationIds.Add(adminOp);
        }
        var current = await db.Set<RoleOperation>().Where(x => x.RoleId == roleId).ToListAsync(ct);
        db.Set<RoleOperation>().RemoveRange(current.Where(c => !operationIds.Contains(c.OperationId)));
        foreach (var opId in operationIds.Distinct().Where(o => current.All(c => c.OperationId != o)))
            db.Set<RoleOperation>().Add(new RoleOperation { Id = Guid.CreateVersion7(), RoleId = roleId, OperationId = opId });
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
    }

    // ----- Chức năng / phân hệ -----
    public Task<List<ModuleDto>> GetModulesAsync(CancellationToken ct)
        => db.Set<Module>().AsNoTracking().OrderBy(m => m.SortOrder)
            .Select(m => new ModuleDto(m.Id, m.Code, m.Name, m.Icon, m.SortOrder, m.IsShow)).ToListAsync(ct);

    public Task<List<OperationDto>> GetOperationsAsync(CancellationToken ct)
        => db.Set<Operation>().AsNoTracking().OrderBy(o => o.SortOrder)
            .Select(o => new OperationDto(o.Id, o.ModuleId, o.ParentId, o.Code, o.Name, o.Route, o.Icon, o.SortOrder, o.IsShow))
            .ToListAsync(ct);

    public async Task<Guid> SaveOperationAsync(Guid? id, SaveOperationRequest req, CancellationToken ct)
    {
        var code = req.Code.Trim().ToUpperInvariant();
        if (await db.Set<Operation>().AnyAsync(o => o.Code == code && o.Id != id, ct))
            throw new AppException(ErrorCodes.Conflict, "Mã chức năng đã tồn tại", 409);
        var op = id is null ? null : await db.Set<Operation>().FirstOrDefaultAsync(o => o.Id == id, ct);
        if (id is not null && op is null) throw AppException.NotFound();
        if (op is null)
        {
            op = new Operation { Id = Guid.CreateVersion7() };
            db.Set<Operation>().Add(op);
        }
        op.ModuleId = req.ModuleId;
        op.ParentId = req.ParentId;
        op.Code = code;
        op.Name = req.Name.Trim();
        op.Route = req.Route;
        op.Icon = req.Icon;
        op.SortOrder = req.SortOrder;
        op.IsShow = req.IsShow;
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
        return op.Id;
    }

    // ----- Người dùng -----
    public async Task<List<AdminUserDto>> GetUsersAsync(string? q, CancellationToken ct)
    {
        var query = db.Set<User>().AsNoTracking();
        if (!string.IsNullOrWhiteSpace(q))
            query = query.Where(u => u.Username.Contains(q) || u.Email.Contains(q) || u.DisplayName.Contains(q));
        var users = await query.OrderBy(u => u.CreatedAt).Take(200).ToListAsync(ct);
        var ids = users.Select(u => u.Id).ToList();
        var ur = await db.Set<UserRole>().AsNoTracking().Where(x => ids.Contains(x.MemberUserId)).ToListAsync(ct);
        return users.Select(u => new AdminUserDto(u.Id, u.Email, u.Username, u.DisplayName,
            ur.Where(x => x.MemberUserId == u.Id).Select(x => x.RoleId).ToList(), u.CreatedAt, u.IsLocked, u.LastSeenAt)).ToList();
    }

    /// <summary>Quản trị viên tạo tài khoản (không cần người dùng tự đăng ký).</summary>
    public async Task<Guid> CreateUserAsync(CreateUserRequest req, CancellationToken ct)
    {
        var user = await auth.CreateUserAsync(req.Email, req.Username, req.Password, req.DisplayName, req.RoleIds is { Count: > 0 } ? req.RoleIds : null, ct);
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
        return user.Id;
    }

    /// <summary>Đặt lại mật khẩu cho người dùng; mọi phiên đăng nhập của họ bị đăng xuất.</summary>
    public async Task ResetPasswordAsync(Guid userId, string newPassword, CancellationToken ct)
    {
        var u = await db.Set<User>().FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound();
        if (LHT.Application.Features.Auth.AuthService.PasswordError(newPassword) is { } pe) throw AppException.Validation(new { newPassword = pe });
        u.PasswordHash = LHT.Application.Features.Auth.AuthService.HashPassword(u, newPassword);
        await db.SaveChangesAsync(ct);
        await auth.RevokeSessionsAsync(userId, null, ct);
    }

    /// <summary>Khoá / mở khoá tài khoản. Khoá → đăng xuất mọi phiên. Không tự khoá mình, không khoá quản trị viên cuối cùng.</summary>
    public async Task SetLockedAsync(Guid adminId, Guid userId, bool locked, CancellationToken ct)
    {
        if (locked && userId == adminId) throw AppException.Validation(new { userId = "Không thể tự khoá tài khoản của mình" });
        var u = await db.Set<User>().FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound();
        if (locked) await EnsureOtherAdminAsync(userId, ct);
        u.IsLocked = locked;
        await db.SaveChangesAsync(ct);
        if (locked) await auth.RevokeSessionsAsync(userId, null, ct);
    }

    /// <summary>Xoá người dùng (xoá vĩnh viễn dữ liệu như khi họ tự xoá tài khoản).</summary>
    public async Task DeleteUserAsync(Guid adminId, Guid userId, CancellationToken ct)
    {
        if (userId == adminId) throw AppException.Validation(new { userId = "Muốn xoá tài khoản của chính mình, dùng Cài đặt → Xoá tài khoản" });
        await EnsureOtherAdminAsync(userId, ct);
        await accounts.PurgeAsync(userId, ct);
        permissions.InvalidateAll();
    }

    /// <summary>Nếu người dùng là ADMIN thì hệ thống phải còn ít nhất một ADMIN khác đang hoạt động.</summary>
    private async Task EnsureOtherAdminAsync(Guid userId, CancellationToken ct)
    {
        var adminRoleId = await db.Set<Role>().Where(r => r.Code == Perm.RoleAdmin).Select(r => r.Id).FirstAsync(ct);
        var isAdmin = await db.Set<UserRole>().AnyAsync(x => x.RoleId == adminRoleId && x.MemberUserId == userId, ct);
        if (isAdmin && !await db.Set<UserRole>().AnyAsync(x => x.RoleId == adminRoleId && x.MemberUserId != userId &&
                db.Set<User>().Any(u => u.Id == x.MemberUserId && !u.IsLocked), ct))
            throw new AppException(ErrorCodes.Conflict, "Hệ thống phải còn ít nhất một quản trị viên đang hoạt động", 409);
    }

    public async Task SetUserRolesAsync(Guid userId, List<Guid> roleIds, CancellationToken ct)
    {
        if (!await db.Set<User>().AnyAsync(u => u.Id == userId, ct)) throw AppException.NotFound();
        // Luôn phải còn ít nhất 1 admin.
        var adminRoleId = await db.Set<Role>().Where(r => r.Code == Perm.RoleAdmin).Select(r => r.Id).FirstAsync(ct);
        if (!roleIds.Contains(adminRoleId) &&
            !await db.Set<UserRole>().AnyAsync(x => x.RoleId == adminRoleId && x.MemberUserId != userId, ct))
            throw new AppException(ErrorCodes.Conflict, "Hệ thống phải còn ít nhất một quản trị viên", 409);

        var current = await db.Set<UserRole>().Where(x => x.MemberUserId == userId).ToListAsync(ct);
        db.Set<UserRole>().RemoveRange(current.Where(c => !roleIds.Contains(c.RoleId)));
        foreach (var rid in roleIds.Distinct().Where(r => current.All(c => c.RoleId != r)))
            db.Set<UserRole>().Add(new UserRole { Id = Guid.CreateVersion7(), MemberUserId = userId, RoleId = rid });
        await db.SaveChangesAsync(ct);
        permissions.InvalidateAll();
    }

    // ----- Nhật ký hệ thống / API -----
    public async Task<LHT.Application.Features.Dtos.Admin.PagedResult<LHT.Application.Features.Dtos.Admin.ApiLogDto>> GetApiLogsAsync(LHT.Application.Features.Dtos.Admin.ApiLogFilterQuery query, CancellationToken ct)
    {
        var q = db.Set<ApiLog>().AsNoTracking();

        if (!string.IsNullOrWhiteSpace(query.Search))
        {
            var s = query.Search.Trim();
            q = q.Where(x => x.Path.Contains(s) || (x.Username != null && x.Username.Contains(s)) || (x.IpAddress != null && x.IpAddress.Contains(s)) || (x.ErrorMessage != null && x.ErrorMessage.Contains(s)));
        }

        if (!string.IsNullOrWhiteSpace(query.Method))
        {
            var m = query.Method.Trim().ToUpperInvariant();
            q = q.Where(x => x.Method == m);
        }

        if (query.StatusCode.HasValue)
        {
            q = q.Where(x => x.StatusCode == query.StatusCode.Value);
        }

        if (query.OnlyErrors == true)
        {
            q = q.Where(x => x.StatusCode >= 400);
        }

        if (query.FromDate.HasValue)
        {
            q = q.Where(x => x.CreatedAt >= query.FromDate.Value);
        }

        if (query.ToDate.HasValue)
        {
            q = q.Where(x => x.CreatedAt <= query.ToDate.Value);
        }

        var total = await q.LongCountAsync(ct);
        var page = Math.Max(1, query.Page);
        var pageSize = Math.Clamp(query.PageSize, 1, 100);
        var totalPages = (int)Math.Ceiling(total / (double)pageSize);

        var items = await q.OrderByDescending(x => x.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(x => new LHT.Application.Features.Dtos.Admin.ApiLogDto(
                x.Id,
                x.CreatedAt,
                x.UserId,
                x.Username,
                x.Method,
                x.Path,
                x.QueryString,
                x.StatusCode,
                x.DurationMs,
                x.IpAddress,
                x.UserAgent,
                x.RequestBody,
                x.ResponseBody,
                x.ErrorMessage))
            .ToListAsync(ct);

        return new LHT.Application.Features.Dtos.Admin.PagedResult<LHT.Application.Features.Dtos.Admin.ApiLogDto>(items, total, page, pageSize, totalPages);
    }

    public async Task<LHT.Application.Features.Dtos.Admin.ApiLogDto> GetApiLogDetailAsync(Guid id, CancellationToken ct)
    {
        var x = await db.Set<ApiLog>().AsNoTracking().FirstOrDefaultAsync(l => l.Id == id, ct) ?? throw AppException.NotFound();
        return new LHT.Application.Features.Dtos.Admin.ApiLogDto(
            x.Id,
            x.CreatedAt,
            x.UserId,
            x.Username,
            x.Method,
            x.Path,
            x.QueryString,
            x.StatusCode,
            x.DurationMs,
            x.IpAddress,
            x.UserAgent,
            x.RequestBody,
            x.ResponseBody,
            x.ErrorMessage);
    }

    public async Task<int> ClearApiLogsAsync(int keepDays, CancellationToken ct)
    {
        var cutoff = DateTimeOffset.UtcNow.AddDays(-Math.Max(1, keepDays));
        return await db.Set<ApiLog>().Where(x => x.CreatedAt < cutoff).ExecuteDeleteAsync(ct);
    }

    public async Task<LHT.Application.Features.Dtos.Admin.ApiLogStatsDto> GetApiLogStatsAsync(CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var startOfToday = new DateTimeOffset(now.Year, now.Month, now.Day, 0, 0, 0, TimeSpan.Zero);

        var total = await db.Set<ApiLog>().LongCountAsync(ct);
        var errors = await db.Set<ApiLog>().Where(x => x.StatusCode >= 400).LongCountAsync(ct);
        var avgMs = total > 0 ? await db.Set<ApiLog>().AverageAsync(x => (double)x.DurationMs, ct) : 0;

        var todayTotal = await db.Set<ApiLog>().Where(x => x.CreatedAt >= startOfToday).LongCountAsync(ct);
        var todayErrors = await db.Set<ApiLog>().Where(x => x.CreatedAt >= startOfToday && x.StatusCode >= 400).LongCountAsync(ct);

        return new LHT.Application.Features.Dtos.Admin.ApiLogStatsDto(total, errors, Math.Round(avgMs, 1), todayTotal, todayErrors);
    }
}
