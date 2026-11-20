namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại danh mục: chi hoặc thu.</summary>
public enum CategoryType : byte { Expense = 1, Income = 2, Event = 3, ActivityTemplate = 4 }
