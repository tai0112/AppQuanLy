namespace LHT.Application.Features.Permissions;

public sealed record MyPermissions(List<string> Roles, List<string> Codes, List<MenuModule> Menu);
