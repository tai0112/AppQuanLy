using LHT.Domain.Common;

namespace LHT.Application.Abstractions;

/// <summary>Repository chung cho mọi entity. Truy vấn tự loại bản ghi đã xoá mềm.</summary>
public interface IRepository<T> where T : BaseEntity
{
    /// <summary>Truy vấn có theo dõi thay đổi (dùng khi cần sửa).</summary>
    IQueryable<T> Query();

    /// <summary>Truy vấn chỉ đọc, nhanh hơn.</summary>
    IQueryable<T> QueryNoTracking();

    Task<T?> GetByIdAsync(Guid id, CancellationToken ct = default);
    Task AddAsync(T entity, CancellationToken ct = default);
    void Update(T entity);

    /// <summary>Xoá mềm (chỉ đặt DeletedAt).</summary>
    void Remove(T entity);
}
