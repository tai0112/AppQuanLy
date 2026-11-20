using System.ComponentModel;
using LHT.Domain.Common;
using LHT.Domain.Enums;

namespace LHT.Domain.Entities;

[Description("Tài khoản / ví tiền")]
public class Account : OwnedEntity
{
    [Description("Tên tài khoản, vd Tiền mặt, Vietcombank")]
    public string Name { get; set; } = null!;

    [Description("Loại: 1=tiền mặt, 2=ngân hàng, 3=ví điện tử, 4=thẻ tín dụng, 99=khác")]
    public AccountType Type { get; set; }

    [Description("Tên icon")]
    public string? Icon { get; set; }

    [Description("Màu (hex, vd #FF8800)")]
    public string? Color { get; set; }

    [Description("Mã tiền tệ của tài khoản")]
    public string CurrencyCode { get; set; } = null!;

    [Description("Số dư ban đầu")]
    public decimal OpeningBalance { get; set; }

    [Description("Có tính vào tổng tài sản không")]
    public bool IncludeInTotal { get; set; } = true;

    [Description("Thứ tự sắp xếp")]
    public int SortOrder { get; set; }

    [Description("Đã lưu trữ (ẩn khỏi danh sách)")]
    public bool IsArchived { get; set; }
}
