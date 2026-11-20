namespace LHT.Application.Features;

public sealed record EventBrief(Guid Id, string Title, DateTimeOffset StartAt, string? Location, Guid? CoverFileId);
