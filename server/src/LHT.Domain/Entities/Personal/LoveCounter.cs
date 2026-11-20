using System.ComponentModel;
using LHT.Domain.Common;

namespace LHT.Domain.Entities;

[Description("Đếm ngày yêu")]
public class LoveCounter : OwnedEntity
{
    [Description("Ngày bắt đầu yêu")]
    public DateOnly StartDate { get; set; }

    [Description("Tên người ấy")]
    public string PartnerName { get; set; } = null!;

    [Description("Sinh nhật người ấy")]
    public DateOnly? PartnerBirthday { get; set; }

    [Description("Tài khoản người ấy trong app (nếu có)")]
    public Guid? PartnerUserId { get; set; }

    [Description("Ảnh của tôi (StoredFiles.Id)")]
    public Guid? MyPhotoFileId { get; set; }

    [Description("Ảnh người ấy (StoredFiles.Id)")]
    public Guid? PartnerPhotoFileId { get; set; }

    [Description("Nhắc trước mốc bao nhiêu ngày")]
    public int MilestoneReminderDays { get; set; } = 3;
}
