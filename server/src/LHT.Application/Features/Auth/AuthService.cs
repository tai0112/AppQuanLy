using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using LHT.Application.Abstractions;
using LHT.Application.Common;
using LHT.Application.Features.Permissions;
using LHT.Domain.Entities;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

namespace LHT.Application.Features.Auth;

public partial class AuthService(IAppDbContext db, ITokenService tokens, TimeProvider clock)
{
    private static readonly PasswordHasher<User> Hasher = new();
    private const int RefreshDays = 30;

    [GeneratedRegex(@"^[a-z0-9_.]{3,30}$")] private static partial Regex UsernameRegex();
    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")] private static partial Regex EmailRegex();

    public async Task<AuthResponse> RegisterAsync(RegisterRequest req, CancellationToken ct)
    {
        if (!req.AcceptTerms) throw AppException.Validation(new { acceptTerms = "Bạn cần đồng ý Điều khoản sử dụng & Chính sách quyền riêng tư" });
        var user = await CreateUserAsync(req.Email, req.Username, req.Password, req.DisplayName, null, ct);
        user.TermsAcceptedAt = clock.GetUtcNow();
        return await IssueAsync(user, ct);
    }

    /// <summary>
    /// Tạo người dùng (chưa lưu): kiểm tra dữ liệu, trùng email / tên đăng nhập, gán vai trò.
    /// <paramref name="roleIds"/> null = vai trò mặc định (người đầu tiên của hệ thống thành ADMIN).
    /// </summary>
    public async Task<User> CreateUserAsync(string emailRaw, string usernameRaw, string password, string displayName, IEnumerable<Guid>? roleIds, CancellationToken ct)
    {
        var email = emailRaw.Trim().ToLowerInvariant();
        var username = usernameRaw.Trim().ToLowerInvariant();
        var errors = new Dictionary<string, string>();
        if (!EmailRegex().IsMatch(email)) errors["email"] = "Email không hợp lệ";
        if (!UsernameRegex().IsMatch(username)) errors["username"] = "Tên đăng nhập 3-30 ký tự: chữ thường, số, dấu _ hoặc .";
        if (PasswordError(password) is { } pe) errors["password"] = pe;
        if (string.IsNullOrWhiteSpace(displayName)) errors["displayName"] = "Bắt buộc";
        if (errors.Count > 0) throw AppException.Validation(errors);

        if (await db.Set<User>().AnyAsync(u => u.Email == email, ct))
            throw new AppException(ErrorCodes.Conflict, "Email đã được sử dụng", 409);
        if (await db.Set<User>().AnyAsync(u => u.Username == username, ct))
            throw new AppException(ErrorCodes.Conflict, "Tên đăng nhập đã được sử dụng", 409);

        var user = new User { Id = Guid.CreateVersion7(), Email = email, Username = username, DisplayName = displayName.Trim() };
        user.PasswordHash = Hasher.HashPassword(user, password);
        db.Set<User>().Add(user);

        List<Guid> roles;
        if (roleIds is null)
        {
            // Vai trò mặc định; người đăng ký đầu tiên của hệ thống là ADMIN.
            roles = await db.Set<Role>().Where(r => r.IsDefault && r.IsActive).Select(r => r.Id).ToListAsync(ct);
            var adminRole = await db.Set<Role>().FirstAsync(r => r.Code == Perm.RoleAdmin, ct);
            if (!await db.Set<UserRole>().AnyAsync(x => x.RoleId == adminRole.Id, ct)) roles.Add(adminRole.Id);
        }
        else
        {
            var wanted = roleIds.ToList();
            roles = await db.Set<Role>().Where(r => wanted.Contains(r.Id)).Select(r => r.Id).ToListAsync(ct);
        }
        foreach (var rid in roles.Distinct())
            db.Set<UserRole>().Add(new UserRole { Id = Guid.CreateVersion7(), MemberUserId = user.Id, RoleId = rid });
        return user;
    }

    /// <summary>Quy tắc mật khẩu: tối thiểu 6 ký tự. Trả về thông báo lỗi hoặc null.</summary>
    public static string? PasswordError(string? password) => password is null || password.Length < 6 ? "Mật khẩu tối thiểu 6 ký tự" : null;

    public static string HashPassword(User user, string password) => Hasher.HashPassword(user, password);

    /// <summary>Tự đổi mật khẩu: cần mật khẩu hiện tại; các phiên đăng nhập trên máy khác bị đăng xuất.</summary>
    public async Task ChangePasswordAsync(Guid me, string current, string next, string? keepRefreshToken, CancellationToken ct)
    {
        var u = await db.Set<User>().FirstOrDefaultAsync(x => x.Id == me, ct) ?? throw AppException.NotFound();
        if (Hasher.VerifyHashedPassword(u, u.PasswordHash, current ?? "") == PasswordVerificationResult.Failed)
            throw AppException.Validation(new { currentPassword = "Mật khẩu hiện tại không đúng" });
        if (PasswordError(next) is { } pe) throw AppException.Validation(new { newPassword = pe });
        u.PasswordHash = Hasher.HashPassword(u, next);
        await db.SaveChangesAsync(ct);
        var keep = keepRefreshToken is null ? null : Hash(keepRefreshToken);
        await RevokeSessionsAsync(me, keep, ct);
    }

    /// <summary>Thu hồi mọi phiên đăng nhập (refresh token) của người dùng, trừ phiên đang dùng nếu có.</summary>
    public async Task RevokeSessionsAsync(Guid userId, string? exceptTokenHash, CancellationToken ct)
    {
        var now = clock.GetUtcNow();
        await db.Set<RefreshToken>().Where(t => t.UserId == userId && t.RevokedAt == null && t.TokenHash != exceptTokenHash)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now), ct);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest req, CancellationToken ct)
    {
        var login = req.Login.Trim().ToLowerInvariant();
        var user = await db.Set<User>().FirstOrDefaultAsync(u => u.Email == login || u.Username == login, ct);
        if (user is null || Hasher.VerifyHashedPassword(user, user.PasswordHash, req.Password) == PasswordVerificationResult.Failed)
            throw new AppException(ErrorCodes.Unauthorized, "Sai tên đăng nhập hoặc mật khẩu", 401);
        if (user.IsLocked) throw new AppException(ErrorCodes.Forbidden, "Tài khoản đã bị khoá. Vui lòng liên hệ quản trị viên.", 403);
        user.LastSeenAt = clock.GetUtcNow();
        return await IssueAsync(user, ct);
    }

    public async Task<AuthResponse> RefreshAsync(string refreshToken, CancellationToken ct)
    {
        var hash = Hash(refreshToken);
        var now = clock.GetUtcNow();
        var stored = await db.Set<RefreshToken>().FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is null || stored.RevokedAt is not null || stored.ExpiresAt < now)
            throw new AppException(ErrorCodes.Unauthorized, "Phiên đăng nhập đã hết hạn", 401);
        stored.RevokedAt = now; // xoay vòng: mỗi refresh token chỉ dùng 1 lần
        var user = await db.Set<User>().FirstOrDefaultAsync(u => u.Id == stored.UserId, ct);
        if (user is null || user.IsLocked)
        {
            await db.SaveChangesAsync(ct);
            throw new AppException(ErrorCodes.Unauthorized, user is null ? "Tài khoản không còn tồn tại" : "Tài khoản đã bị khoá", 401);
        }
        user.LastSeenAt = now;
        return await IssueAsync(user, ct);
    }

    public async Task LogoutAsync(string refreshToken, CancellationToken ct)
    {
        var hash = Hash(refreshToken);
        var stored = await db.Set<RefreshToken>().FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (stored is null) return;
        stored.RevokedAt = clock.GetUtcNow();
        await db.SaveChangesAsync(ct);
    }

    public async Task<UserProfile> GetProfileAsync(Guid userId, CancellationToken ct)
    {
        var u = await db.Set<User>().AsNoTracking().FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound();
        return ToProfile(u);
    }

    public async Task<UserProfile> UpdateProfileAsync(Guid userId, UpdateProfileRequest req, CancellationToken ct)
    {
        var u = await db.Set<User>().FirstOrDefaultAsync(x => x.Id == userId, ct) ?? throw AppException.NotFound();
        if (string.IsNullOrWhiteSpace(req.DisplayName)) throw AppException.Validation(new { displayName = "Bắt buộc" });
        u.DisplayName = req.DisplayName.Trim();
        u.Bio = req.Bio;
        u.AvatarFileId = req.AvatarFileId;
        u.Birthday = req.Birthday;
        await db.SaveChangesAsync(ct);
        return ToProfile(u);
    }

    private async Task<AuthResponse> IssueAsync(User user, CancellationToken ct)
    {
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48)).Replace('+', '-').Replace('/', '_').TrimEnd('=');
        db.Set<RefreshToken>().Add(new RefreshToken
        {
            Id = Guid.CreateVersion7(), UserId = user.Id, TokenHash = Hash(raw), ExpiresAt = clock.GetUtcNow().AddDays(RefreshDays),
        });
        await db.SaveChangesAsync(ct);
        var (access, exp) = tokens.CreateAccessToken(user);
        return new AuthResponse(access, exp, raw, ToProfile(user));
    }

    private static UserProfile ToProfile(User u) => new(u.Id, u.Email, u.Username, u.DisplayName, u.AvatarFileId, u.Bio, u.Birthday);

    private static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value)));
}
