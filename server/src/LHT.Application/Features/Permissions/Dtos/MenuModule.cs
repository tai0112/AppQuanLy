namespace LHT.Application.Features.Permissions;

public sealed record MenuModule(Guid Id, string Code, string Name, string? Icon, int SortOrder, List<MenuOperation> Operations);
