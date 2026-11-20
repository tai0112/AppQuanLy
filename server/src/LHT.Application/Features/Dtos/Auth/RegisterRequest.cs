namespace LHT.Application.Features;

/// <param name="AcceptTerms">Bắt buộc true: đồng ý Điều khoản sử dụng (không dung thứ nội dung phản cảm / lạm dụng) & Chính sách quyền riêng tư.</param>
public sealed record RegisterRequest(string Email, string Username, string Password, string DisplayName, bool AcceptTerms = false);
