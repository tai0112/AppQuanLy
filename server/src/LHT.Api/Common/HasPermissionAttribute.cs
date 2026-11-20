using Microsoft.AspNetCore.Authorization;

namespace LHT.Api.Common;

/// <summary>
/// Yêu cầu quyền theo mã chức năng, kiểm tra động từ DB (VaiTro ↔ ChucNang).
/// Ví dụ: [HasPermission(Perm.QuanTriVaiTro)]
/// </summary>
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class HasPermissionAttribute(string code) : AuthorizeAttribute(PermissionPolicyProvider.Prefix + code);
