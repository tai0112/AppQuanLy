namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại cảm xúc.</summary>
public enum ReactionKind : byte { Like = 1, Love = 2, Haha = 3, Wow = 4, Sad = 5, Angry = 6 }
