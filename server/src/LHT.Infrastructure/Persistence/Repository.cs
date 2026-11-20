using LHT.Application.Abstractions;
using LHT.Domain.Common;
using Microsoft.EntityFrameworkCore;

namespace LHT.Infrastructure.Persistence;

public class Repository<T>(AppDbContext db) : IRepository<T> where T : BaseEntity
{
    private readonly DbSet<T> _set = db.Set<T>();

    public IQueryable<T> Query() => _set;
    public IQueryable<T> QueryNoTracking() => _set.AsNoTracking();

    public Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default)
        => _set.FirstOrDefaultAsync(x => x.Id == id, ct);

    public async Task AddAsync(T entity, CancellationToken ct = default) => await _set.AddAsync(entity, ct);
    public void Update(T entity) => _set.Update(entity);

    // AuditInterceptor sẽ chuyển thành xoá mềm.
    public void Remove(T entity) => _set.Remove(entity);
}
