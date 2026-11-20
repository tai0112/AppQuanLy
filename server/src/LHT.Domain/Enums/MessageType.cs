namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại tin nhắn.</summary>
public enum MessageType : byte { Text = 1, Image = 2, System = 3 }
