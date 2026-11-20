namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại thông báo.</summary>
public enum NotificationType : byte
{
    FriendRequest = 1, FriendAccepted = 2, NewMessage = 3, EventInvite = 4, EventChanged = 5,
    NewPost = 6, NewComment = 7, NewReaction = 8, Tagged = 9,
    CoupleRequest = 10, CoupleAccepted = 11, CoupleEnded = 12
}
