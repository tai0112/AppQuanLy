namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại giao dịch.</summary>
public enum TransactionType : byte { Expense = 1, Income = 2, Transfer = 3 }
