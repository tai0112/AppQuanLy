namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Lượng máu kinh.</summary>
public enum CycleFlow : byte { Light = 1, Medium = 2, Heavy = 3 }
