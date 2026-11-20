namespace LHT.Application.Abstractions;

/// <summary>Lưu mọi thay đổi trong một giao dịch DB.</summary>
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
    Task ExecuteInTransactionAsync(Func<CancellationToken, Task> action, CancellationToken ct = default);
}
