using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features.Permissions;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[Route("api/v1/admin")]
public class AdminController(AdminService admin) : BaseApiController
{
    [HttpGet("roles"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<List<RoleDto>>>> Roles(CancellationToken ct) => OkResponse(await admin.GetRolesAsync(ct));

    [HttpPost("roles"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<Guid>>> CreateRole(SaveRoleRequest req, CancellationToken ct) => OkResponse(await admin.SaveRoleAsync(null, req, ct));

    [HttpPut("roles/{id:guid}"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<Guid>>> UpdateRole(Guid id, SaveRoleRequest req, CancellationToken ct) => OkResponse(await admin.SaveRoleAsync(id, req, ct));

    [HttpDelete("roles/{id:guid}"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<bool>>> DeleteRole(Guid id, CancellationToken ct)
    {
        await admin.DeleteRoleAsync(id, ct);
        return OkResponse(true);
    }

    [HttpPut("roles/{id:guid}/operations"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<bool>>> SetRoleOperations(Guid id, SetIdsRequest req, CancellationToken ct)
    {
        await admin.SetRoleOperationsAsync(id, req.Ids, ct);
        return OkResponse(true);
    }

    [HttpGet("modules"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<List<ModuleDto>>>> Modules(CancellationToken ct) => OkResponse(await admin.GetModulesAsync(ct));

    [HttpGet("operations"), HasPermission(Perm.QuanTriVaiTro)]
    public async Task<ActionResult<ApiResponse<List<OperationDto>>>> Operations(CancellationToken ct) => OkResponse(await admin.GetOperationsAsync(ct));

    [HttpPost("operations"), HasPermission(Perm.QuanTriChucNang)]
    public async Task<ActionResult<ApiResponse<Guid>>> CreateOperation(SaveOperationRequest req, CancellationToken ct) => OkResponse(await admin.SaveOperationAsync(null, req, ct));

    [HttpPut("operations/{id:guid}"), HasPermission(Perm.QuanTriChucNang)]
    public async Task<ActionResult<ApiResponse<Guid>>> UpdateOperation(Guid id, SaveOperationRequest req, CancellationToken ct) => OkResponse(await admin.SaveOperationAsync(id, req, ct));

    [HttpGet("users"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<List<AdminUserDto>>>> Users([FromQuery] string? q, CancellationToken ct) => OkResponse(await admin.GetUsersAsync(q, ct));

    [HttpPost("users"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<Guid>>> CreateUser(CreateUserRequest req, CancellationToken ct) => OkResponse(await admin.CreateUserAsync(req, ct));

    [HttpPost("users/{id:guid}/password"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<bool>>> ResetPassword(Guid id, ResetPasswordRequest req, CancellationToken ct)
    {
        await admin.ResetPasswordAsync(id, req.NewPassword, ct);
        return OkResponse(true);
    }

    [HttpPost("users/{id:guid}/lock"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<bool>>> SetLocked(Guid id, SetLockedRequest req, CancellationToken ct)
    {
        await admin.SetLockedAsync(CurrentUserId, id, req.Locked, ct);
        return OkResponse(true);
    }

    [HttpDelete("users/{id:guid}"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<bool>>> DeleteUser(Guid id, CancellationToken ct)
    {
        await admin.DeleteUserAsync(CurrentUserId, id, ct);
        return OkResponse(true);
    }

    [HttpPut("users/{id:guid}/roles"), HasPermission(Perm.QuanTriNguoiDung)]
    public async Task<ActionResult<ApiResponse<bool>>> SetUserRoles(Guid id, SetIdsRequest req, CancellationToken ct)
    {
        await admin.SetUserRolesAsync(id, req.Ids, ct);
        return OkResponse(true);
    }
}
