namespace LHT.Application.Features.Permissions;

public interface IPermissionService
{
    Task<HashSet<string>> GetCodesAsync(Guid userId, CancellationToken ct = default);
    Task<bool> HasAsync(Guid userId, string code, CancellationToken ct = default);
    Task<MyPermissions> GetMineAsync(Guid userId, CancellationToken ct = default);
    /// <summary>Xoá cache quyền của mọi người (gọi khi đổi gán quyền).</summary>
    void InvalidateAll();
}
