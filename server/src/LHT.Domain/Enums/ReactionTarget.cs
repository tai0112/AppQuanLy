namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Đối tượng được thả cảm xúc.</summary>
public enum ReactionTarget : byte { Post = 1, Comment = 2 }
