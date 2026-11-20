using LHT.Application.Abstractions;
using Microsoft.Extensions.Configuration;

namespace LHT.Infrastructure.Services;

/// <summary>Lưu file trên ổ đĩa: {Storage:Root}/{userId}/{fileId}{ext}. Sau này thay bằng MinIO/S3 cùng interface.</summary>
public class LocalFileStorage(IConfiguration config) : IFileStorage
{
    private readonly string _root = Path.GetFullPath(config["Storage:Root"] ?? "uploads");

    public async Task<string> SaveAsync(Guid userId, Guid fileId, string extension, Stream content, CancellationToken ct = default)
    {
        var relative = Path.Combine(userId.ToString("N"), fileId.ToString("N") + extension);
        var full = Path.Combine(_root, relative);
        Directory.CreateDirectory(Path.GetDirectoryName(full)!);
        await using var fs = File.Create(full);
        await content.CopyToAsync(fs, ct);
        return relative.Replace('\\', '/');
    }

    public Task<Stream?> OpenReadAsync(string path, CancellationToken ct = default)
    {
        var full = Path.GetFullPath(Path.Combine(_root, path));
        if (!full.StartsWith(_root, StringComparison.Ordinal) || !File.Exists(full)) return Task.FromResult<Stream?>(null);
        return Task.FromResult<Stream?>(File.OpenRead(full));
    }

    public Task DeleteAsync(string path, CancellationToken ct = default)
    {
        var full = Path.GetFullPath(Path.Combine(_root, path));
        if (full.StartsWith(_root, StringComparison.Ordinal) && File.Exists(full)) File.Delete(full);
        return Task.CompletedTask;
    }
}
