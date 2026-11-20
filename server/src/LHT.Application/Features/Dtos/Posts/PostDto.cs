using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record PostDto(
    Guid Id, UserSummary Author, string? Content, PostVisibility Visibility,
    IReadOnlyList<Guid> PhotoFileIds, IReadOnlyList<UserSummary> Tagged,
    EventBrief? Event, string? Location, string? Feeling,
    int ReactionCount, int CommentCount, ReactionKind? MyReaction, DateTimeOffset CreatedAt);
