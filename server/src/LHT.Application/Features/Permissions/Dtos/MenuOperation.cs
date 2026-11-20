namespace LHT.Application.Features.Permissions;

public sealed record MenuOperation(Guid Id, string Code, string Name, string? Route, string? Icon, int SortOrder, Guid? ParentId);
