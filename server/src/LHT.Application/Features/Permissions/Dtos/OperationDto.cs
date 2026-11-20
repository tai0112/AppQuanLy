namespace LHT.Application.Features.Permissions;

public sealed record OperationDto(Guid Id, Guid ModuleId, Guid? ParentId, string Code, string Name, string? Route, string? Icon, int SortOrder, bool IsShow);
