using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Permissions;

/// <summary>
/// Chạy mỗi lần khởi động: thêm phân hệ/chức năng/vai trò còn thiếu (không ghi đè chỉnh sửa của admin).
/// ADMIN luôn có mọi chức năng; USER nhận các chức năng người dùng khi chức năng mới được tạo.
/// </summary>
public class PermissionSeeder(IAppDbContext db)
{
    public async Task SeedAsync(CancellationToken ct = default)
    {
        var admin = await EnsureRoleAsync(Perm.RoleAdmin, "Quản trị viên", "Toàn quyền hệ thống", isDefault: false, ct);
        var user = await EnsureRoleAsync(Perm.RoleUser, "Người dùng", "Quyền mặc định khi đăng ký", isDefault: true, ct);

        var modules = await db.Set<Module>().ToListAsync(ct);
        var ops = await db.Set<Operation>().ToListAsync(ct);
        var roleOps = await db.Set<RoleOperation>().ToListAsync(ct);

        foreach (var ms in PermissionCatalog.Modules)
        {
            var module = modules.FirstOrDefault(m => m.Code == ms.Code);
            if (module is null)
            {
                module = new Module { Id = Guid.CreateVersion7(), Code = ms.Code, Name = ms.Name, Icon = ms.Icon, SortOrder = ms.Order };
                db.Set<Module>().Add(module);
                modules.Add(module);
            }

            var order = 0;
            foreach (var os in ms.Operations)
            {
                order++;
                var op = ops.FirstOrDefault(o => o.Code == os.Code);
                if (op is null)
                {
                    op = new Operation
                    {
                        Id = Guid.CreateVersion7(), ModuleId = module.Id, Code = os.Code, Name = os.Name,
                        Route = os.Route, Icon = os.Icon, SortOrder = ms.Order * 100 + order,
                    };
                    db.Set<Operation>().Add(op);
                    ops.Add(op);
                    if (os.ForUser) Grant(user.Id, op.Id, roleOps);
                }
            }
        }

        foreach (var op in ops) Grant(admin.Id, op.Id, roleOps);
        await db.SaveChangesAsync(ct);
    }

    private void Grant(Guid roleId, Guid opId, List<RoleOperation> existing)
    {
        if (existing.Any(x => x.RoleId == roleId && x.OperationId == opId)) return;
        var ro = new RoleOperation { Id = Guid.CreateVersion7(), RoleId = roleId, OperationId = opId };
        db.Set<RoleOperation>().Add(ro);
        existing.Add(ro);
    }

    private async Task<Role> EnsureRoleAsync(string code, string name, string desc, bool isDefault, CancellationToken ct)
    {
        var role = await db.Set<Role>().FirstOrDefaultAsync(r => r.Code == code, ct);
        if (role is not null) return role;
        role = new Role { Id = Guid.CreateVersion7(), Code = code, Name = name, Description = desc, IsSystem = true, IsDefault = isDefault };
        db.Set<Role>().Add(role);
        return role;
    }
}
