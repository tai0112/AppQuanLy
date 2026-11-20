namespace LHT.Application.Abstractions;

/// <summary>Lưu trữ file (ổ đĩa local, sau này MinIO/S3).</summary>
public interface IFileStorage
{
    Task<string> SaveAsync(Guid userId, Guid fileId, string extension, Stream content, CancellationToken ct = default);
    Task<Stream?> OpenReadAsync(string path, CancellationToken ct = default);
    Task DeleteAsync(string path, CancellationToken ct = default);
}
