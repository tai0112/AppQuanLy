using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Nhật ký truy cập và gọi API của hệ thống")]
public class ApiLog : BaseEntity
{
    [Description("Mã người dùng (nếu đã đăng nhập)")]
    public Guid? UserId { get; set; }

    [Description("Tên đăng nhập")]
    public string? Username { get; set; }

    [Description("Phương thức HTTP: GET, POST, PUT, DELETE...")]
    public string Method { get; set; } = null!;

    [Description("Đường dẫn API")]
    public string Path { get; set; } = null!;

    [Description("Tham số truy vấn")]
    public string? QueryString { get; set; }

    [Description("Mã trạng thái HTTP: 200, 400, 401, 500...")]
    public int StatusCode { get; set; }

    [Description("Thời gian xử lý tính bằng mili-giây")]
    public long DurationMs { get; set; }

    [Description("Địa chỉ IP client")]
    public string? IpAddress { get; set; }

    [Description("Trình duyệt hoặc ứng dụng gọi API")]
    public string? UserAgent { get; set; }

    [Description("Nội dung body gửi lên (đã che mật khẩu)")]
    public string? RequestBody { get; set; }

    [Description("Nội dung phản hồi hoặc thông điệp lỗi")]
    public string? ResponseBody { get; set; }

    [Description("Chi tiết lỗi / Exception nếu có")]
    public string? ErrorMessage { get; set; }
}

