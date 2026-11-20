using LHT.Domain.Enums;

namespace LHT.Application.Features;

public sealed record CreatePostRequest(
    Guid Id, string? Content, PostVisibility Visibility, List<Guid>? AudienceIds, List<Guid>? TagIds,
    List<Guid>? PhotoFileIds, Guid? EventId, Guid? JarId, string? Location, string? Feeling);
