namespace LHT.Application.Features;

public sealed record FileDto(Guid Id, string Url, string MimeType, long Size);
