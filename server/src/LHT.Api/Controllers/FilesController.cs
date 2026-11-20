using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Files;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

public class FilesController(FileService files) : BaseApiController
{
    [HttpPost]
    [RequestSizeLimit(FileService.MaxSize + 1024 * 1024)]
    public async Task<ActionResult<ApiResponse<FileDto>>> Upload([FromForm] IFormFile file, [FromForm] Guid? id, CancellationToken ct)
    {
        await using var stream = file.OpenReadStream();
        return OkResponse(await files.UploadAsync(CurrentUserId, id, stream, file.FileName, file.ContentType, file.Length, ct));
    }
}
