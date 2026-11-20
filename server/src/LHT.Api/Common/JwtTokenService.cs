using LHT.Application.Abstractions;
using LHT.Domain.Entities;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;
using System.Security.Claims;
using System.Text;

namespace LHT.Api.Common;

/// <summary>Tạo JWT access token (claim sub = UserId).</summary>
public class JwtTokenService(IConfiguration config, TimeProvider clock) : ITokenService
{
    public (string Token, DateTimeOffset ExpiresAt) CreateAccessToken(User user)
    {
        var expires = clock.GetUtcNow().AddMinutes(config.GetValue("Jwt:AccessTokenMinutes", 60));
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(config["Jwt:Key"]!));
        var token = new JsonWebTokenHandler().CreateToken(new SecurityTokenDescriptor
        {
            Issuer = config["Jwt:Issuer"],
            Audience = config["Jwt:Audience"],
            Expires = expires.UtcDateTime,
            Subject = new ClaimsIdentity([
                new Claim("sub", user.Id.ToString()),
                new Claim("name", user.Username),
            ]),
            SigningCredentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256),
        });
        return (token, expires);
    }
}
