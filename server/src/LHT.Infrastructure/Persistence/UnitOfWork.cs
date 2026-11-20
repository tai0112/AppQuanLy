using LHT.Application.Abstractions;
using Microsoft.EntityFrameworkCore;

namespace LHT.Infrastructure.Persistence;

public class UnitOfWork(AppDbContext db) : IUnitOfWork
{
    public Task<int> SaveChangesAsync(CancellationToken ct = default) => db.SaveChangesAsync(ct);

    public async Task ExecuteInTransactionAsync(Func<CancellationToken, Task> action, CancellationToken ct = default)
    {
        // Dùng execution strategy để tương thích với EnableRetryOnFailure của SQL Server.
        var strategy = db.Database.CreateExecutionStrategy();
        await strategy.ExecuteAsync(async () =>
        {
            await using var tx = await db.Database.BeginTransactionAsync(ct);
            await action(ct);
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
        });
    }
}
