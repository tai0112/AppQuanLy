namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Vai trò trong lịch trình / kế hoạch / nhóm chat.</summary>
public enum MemberRole : byte { Owner = 1, Editor = 2, Viewer = 3 }
