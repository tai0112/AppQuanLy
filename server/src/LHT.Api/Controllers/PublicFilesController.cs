using LHT.Application.Features.Files;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

/// <summary>Xem ảnh: /files/{id}. Id là UUID ngẫu nhiên nên không đoán được; cache 1 năm vì nội dung không đổi.</summary>
[ApiController]
[AllowAnonymous]
[Route("files")]
public class PublicFilesController(FileService files) : ControllerBase
{
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> Get(Guid id, CancellationToken ct)
    {
        var result = await files.OpenAsync(id, ct);
        if (result is null) return NotFound();
        Response.Headers.CacheControl = "public, max-age=31536000, immutable";
        return File(result.Value.Content, result.Value.File.MimeType);
    }
}
