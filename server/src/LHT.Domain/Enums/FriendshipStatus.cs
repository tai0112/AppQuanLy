namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Trạng thái quan hệ bạn bè.</summary>
public enum FriendshipStatus : byte { Pending = 1, Accepted = 2, Blocked = 3 }
