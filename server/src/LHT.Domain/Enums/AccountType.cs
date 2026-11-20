namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại tài khoản/ví.</summary>
public enum AccountType : byte { Cash = 1, Bank = 2, EWallet = 3, CreditCard = 4, Other = 99 }
