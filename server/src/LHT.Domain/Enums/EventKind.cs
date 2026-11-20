namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại lịch trình.</summary>
public enum EventKind : byte { Outing = 1, Work = 2, Other = 99 }
