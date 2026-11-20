namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Đối tượng được theo dõi chu kỳ.</summary>
public enum CycleSubject : byte { Self = 1, Partner = 2 }
