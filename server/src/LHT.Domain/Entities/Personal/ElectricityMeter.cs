using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Công tơ điện (mỗi tầng/phòng một cái): dùng riêng hoặc cho thuê")]
public class ElectricityMeter : OwnedEntity
{
    [Description("Tên công tơ, vd Tầng 3")]
    public string Name { get; set; } = null!;

    [Description("Loại: 1=nhà dùng (khoản chi), 2=cho thuê (khoản thu)")]
    public byte Kind { get; set; } = 1;

    [Description("Tên người thuê (khi cho thuê)")]
    public string? TenantName { get; set; }

    [Description("Bảng giá áp dụng cho công tơ này")]
    public Guid PriceTableId { get; set; }

    [Description("Chỉ số lúc bắt đầu theo dõi")]
    public int InitialIndex { get; set; }

    [Description("Danh mục dùng khi tạo giao dịch (NULL = tự chọn theo loại)")]
    public Guid? CategoryId { get; set; }

    [Description("Tài khoản dùng khi tạo giao dịch (NULL = tài khoản mặc định)")]
    public Guid? AccountId { get; set; }

    [Description("Thứ tự hiển thị")]
    public int SortOrder { get; set; }

    [Description("Đã ngừng theo dõi")]
    public bool IsArchived { get; set; }

    [Description("Ghi chú")]
    public string? Note { get; set; }
}
