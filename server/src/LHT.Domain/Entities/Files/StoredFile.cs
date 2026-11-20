using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("File đã upload lên server (ảnh)")]
public class StoredFile : OwnedEntity
{
    [Description("Đường dẫn lưu trữ tương đối")]
    public string Path { get; set; } = null!;

    [Description("Đường dẫn ảnh thu nhỏ")]
    public string? ThumbPath { get; set; }

    [Description("Tên file gốc")]
    public string? OriginalName { get; set; }

    [Description("Kiểu MIME, vd image/jpeg")]
    public string MimeType { get; set; } = null!;

    [Description("Dung lượng (byte)")]
    public long Size { get; set; }

    [Description("Chiều rộng ảnh (px)")]
    public int? Width { get; set; }

    [Description("Chiều cao ảnh (px)")]
    public int? Height { get; set; }
}
