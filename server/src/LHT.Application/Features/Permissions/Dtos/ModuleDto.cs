namespace LHT.Application.Features.Permissions;

public sealed record ModuleDto(Guid Id, string Code, string Name, string? Icon, int SortOrder, bool IsShow);
