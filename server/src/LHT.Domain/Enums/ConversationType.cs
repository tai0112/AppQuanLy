namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại hội thoại.</summary>
public enum ConversationType : byte { Direct = 1, Group = 2 }
