namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Quyền xem bài viết.</summary>
public enum PostVisibility : byte { Friends = 1, Private = 2, Custom = 3 }
