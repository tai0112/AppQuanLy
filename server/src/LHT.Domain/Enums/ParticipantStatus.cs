namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Trạng thái tham gia lịch trình chung.</summary>
public enum ParticipantStatus : byte { Invited = 1, Accepted = 2, Declined = 3 }
