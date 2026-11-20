namespace LHT.Domain.Common;

/// <summary>Đánh dấu bảng hỗ trợ xoá mềm.</summary>
public interface ISoftDelete
{
    DateTimeOffset? DeletedAt { get; set; }
}
