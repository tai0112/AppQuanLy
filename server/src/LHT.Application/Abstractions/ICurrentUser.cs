namespace LHT.Application.Abstractions;

/// <summary>Thông tin người dùng đang gọi API (lấy từ JWT).</summary>
public interface ICurrentUser
{
    Guid? UserId { get; }
    bool IsAuthenticated { get; }

    /// <summary>Lấy UserId, ném lỗi 401 nếu chưa đăng nhập.</summary>
    Guid RequireUserId();
}
