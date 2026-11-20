using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Quan hệ bạn bè / lời mời kết bạn")]
public class Friendship : BaseEntity
{
    [Description("Người gửi lời mời")]
    public Guid RequesterId { get; set; }

    [Description("Người nhận lời mời")]
    public Guid AddresseeId { get; set; }

    [Description("Trạng thái: 1=chờ, 2=bạn bè, 3=chặn")]
    public FriendshipStatus Status { get; set; } = FriendshipStatus.Pending;

    [Description("Thời điểm chấp nhận")]
    public DateTimeOffset? AcceptedAt { get; set; }

    [Description("Cặp đôi: NULL=không, 1=đang chờ xác nhận, 2=đã là người yêu")]
    public CoupleStatus? CoupleStatus { get; set; }

    [Description("Người gửi lời mời làm người yêu")]
    public Guid? CoupleRequesterId { get; set; }

    [Description("Thời điểm hai người xác nhận là người yêu")]
    public DateTimeOffset? CoupleSince { get; set; }
}
