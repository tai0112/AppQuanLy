using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Files;

public class FileService(IAppDbContext db, IFileStorage storage)
{
    public const long MaxSize = 15 * 1024 * 1024;

    private static readonly Dictionary<string, string> AllowedTypes = new()
    {
        ["image/jpeg"] = ".jpg", ["image/png"] = ".png", ["image/webp"] = ".webp", ["image/gif"] = ".gif", ["image/heic"] = ".heic",
    };

    /// <summary>Upload ảnh. Id do app sinh để có thể gắn vào bản ghi trước khi upload (offline). Gửi lại cùng Id không bị trùng.</summary>
    public async Task<FileDto> UploadAsync(Guid me, Guid? fileId, Stream content, string? fileName, string contentType, long length, CancellationToken ct)
    {
        if (length <= 0 || length > MaxSize) throw AppException.Validation(new { file = "Ảnh tối đa 15MB" });
        if (!AllowedTypes.TryGetValue(contentType.ToLowerInvariant(), out var ext))
            throw AppException.Validation(new { file = "Chỉ hỗ trợ ảnh JPG, PNG, WEBP, GIF, HEIC" });

        var id = fileId is { } g && g != Guid.Empty ? g : Guid.CreateVersion7();
        var existing = await db.Set<StoredFile>().IgnoreQueryFilters().AsNoTracking().FirstOrDefaultAsync(f => f.Id == id, ct);
        if (existing is not null)
            return existing.UserId == me ? ToDto(existing) : throw AppException.Forbidden();

        var path = await storage.SaveAsync(me, id, ext, content, ct);
        var file = new StoredFile { Id = id, UserId = me, Path = path, OriginalName = fileName, MimeType = contentType, Size = length };
        db.Set<StoredFile>().Add(file);
        await db.SaveChangesAsync(ct);
        return ToDto(file);
    }

    public async Task<(StoredFile File, Stream Content)?> OpenAsync(Guid id, CancellationToken ct)
    {
        var file = await db.Set<StoredFile>().AsNoTracking().FirstOrDefaultAsync(f => f.Id == id, ct);
        if (file is null) return null;
        var stream = await storage.OpenReadAsync(file.Path, ct);
        return stream is null ? null : (file, stream);
    }

    private static FileDto ToDto(StoredFile f) => new(f.Id, $"/files/{f.Id}", f.MimeType, f.Size);
}
