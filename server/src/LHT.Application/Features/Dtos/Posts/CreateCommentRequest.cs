namespace LHT.Application.Features;

public sealed record CreateCommentRequest(Guid? Id, string Content, Guid? ParentId);
