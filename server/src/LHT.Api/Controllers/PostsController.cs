using LHT.Api.Common;
using LHT.Application.Common;
using LHT.Application.Features;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using Microsoft.AspNetCore.Mvc;

namespace LHT.Api.Controllers;

[HasPermission(Perm.BaiViet)]
public class PostsController(PostService posts) : BaseApiController
{
    [HttpGet("feed")]
    public async Task<ActionResult<ApiResponse<CursorPage<PostDto>>>> Feed([FromQuery] DateTimeOffset? before, [FromQuery] int limit = 20, CancellationToken ct = default)
        => OkResponse(await posts.FeedAsync(CurrentUserId, before, limit, ct));

    [HttpGet("user/{userId:guid}")]
    public async Task<ActionResult<ApiResponse<CursorPage<PostDto>>>> ByUser(Guid userId, [FromQuery] DateTimeOffset? before, [FromQuery] int limit = 20, CancellationToken ct = default)
        => OkResponse(await posts.ByUserAsync(CurrentUserId, userId, before, limit, ct));

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<ApiResponse<PostDto>>> Get(Guid id, CancellationToken ct)
        => OkResponse(await posts.GetAsync(CurrentUserId, id, ct));

    [HttpPost]
    public async Task<ActionResult<ApiResponse<PostDto>>> Create(CreatePostRequest req, CancellationToken ct)
        => OkResponse(await posts.CreateAsync(CurrentUserId, req, ct));

    [HttpDelete("{id:guid}")]
    public async Task<ActionResult<ApiResponse<bool>>> Delete(Guid id, CancellationToken ct)
    {
        await posts.DeleteAsync(CurrentUserId, id, ct);
        return OkResponse(true);
    }

    [HttpPost("{id:guid}/reactions")]
    public async Task<ActionResult<ApiResponse<PostDto>>> React(Guid id, ReactRequest req, CancellationToken ct)
        => OkResponse(await posts.ReactAsync(CurrentUserId, id, req.Kind, ct));

    [HttpDelete("{id:guid}/reactions")]
    public async Task<ActionResult<ApiResponse<PostDto>>> Unreact(Guid id, CancellationToken ct)
        => OkResponse(await posts.ReactAsync(CurrentUserId, id, null, ct));

    [HttpGet("{id:guid}/comments")]
    public async Task<ActionResult<ApiResponse<List<CommentDto>>>> Comments(Guid id, CancellationToken ct)
        => OkResponse(await posts.CommentsAsync(CurrentUserId, id, ct));

    [HttpPost("{id:guid}/comments")]
    public async Task<ActionResult<ApiResponse<CommentDto>>> Comment(Guid id, CreateCommentRequest req, CancellationToken ct)
        => OkResponse(await posts.AddCommentAsync(CurrentUserId, id, req, ct));
}
