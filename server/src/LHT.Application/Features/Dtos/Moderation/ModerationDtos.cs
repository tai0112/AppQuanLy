using LHT.Domain.Enums;

namespace LHT.Application.Features;

/// <param name="Block">Đồng thời chặn người đăng nội dung.</param>
public sealed record CreateReportRequest(ReportTarget TargetType, Guid TargetId, ReportReason Reason, string? Note, bool Block = false);

public sealed record ReportDto(
    Guid Id, UserSummary Reporter, ReportTarget TargetType, Guid TargetId, UserSummary? TargetUser,
    ReportReason Reason, string? Note, string? Preview, ReportStatus Status, DateTimeOffset CreatedAt, DateTimeOffset? HandledAt);

/// <param name="Remove">true = gỡ nội dung vi phạm; false = bỏ qua báo cáo.</param>
public sealed record ResolveReportRequest(bool Remove);

public sealed record DeleteAccountRequest(string Password);
