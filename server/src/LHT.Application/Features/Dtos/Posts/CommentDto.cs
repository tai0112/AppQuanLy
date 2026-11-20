namespace LHT.Application.Features;

public sealed record CommentDto(Guid Id, Guid PostId, UserSummary Author, Guid? ParentId, string Content, DateTimeOffset CreatedAt);
