namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Chu kỳ tính định mức.</summary>
public enum BudgetPeriod : byte { Day = 1, Week = 2, Month = 3, Year = 4 }
