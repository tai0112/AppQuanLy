namespace LHT.Domain.Enums;

// Lưu trong DB dưới dạng số nguyên (tinyint/int). Không đổi giá trị số đã có, chỉ thêm mới.

/// <summary>Loại đối tượng có ảnh đính kèm.</summary>
public enum AttachmentOwnerType : byte { Transaction = 1, Event = 2, Post = 3, Message = 4, ElectricityBill = 5, SavingsJar = 6 }
