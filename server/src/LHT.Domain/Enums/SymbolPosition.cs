namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Vị trí ký hiệu tiền tệ so với số tiền.</summary>
public enum SymbolPosition : byte { After = 1, Before = 2 }
