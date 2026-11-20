namespace LHT.Domain.Enums;

/// <summary>Loại nội dung bị báo cáo.</summary>
public enum ReportTarget : byte { Post = 1, Comment = 2, User = 3, Message = 4 }

/// <summary>Lý do báo cáo.</summary>
public enum ReportReason : byte { Spam = 1, Harassment = 2, Sexual = 3, Violence = 4, Hate = 5, Scam = 6, Other = 99 }

/// <summary>Trạng thái xử lý báo cáo.</summary>
public enum ReportStatus : byte { Open = 1, Removed = 2, Dismissed = 3 }
