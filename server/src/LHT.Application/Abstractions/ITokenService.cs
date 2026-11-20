using LHT.Domain.Entities;

namespace LHT.Application.Abstractions;

/// <summary>Cấp JWT access token.</summary>
public interface ITokenService
{
    (string Token, DateTimeOffset ExpiresAt) CreateAccessToken(User user);
}
