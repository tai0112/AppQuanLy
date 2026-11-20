namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Nền tảng thiết bị.</summary>
public enum DevicePlatform : byte { Ios = 1, Android = 2 }
