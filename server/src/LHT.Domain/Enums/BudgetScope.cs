namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Phạm vi áp dụng định mức.</summary>
public enum BudgetScope : byte { Total = 1, Category = 2, Account = 3 }
