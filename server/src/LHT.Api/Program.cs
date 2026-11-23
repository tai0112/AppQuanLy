using System.Text;
using LHT.Api.Common;
using LHT.Api.Hubs;
using LHT.Application;
using LHT.Application.Abstractions;
using LHT.Application.Features.Permissions;
using LHT.Infrastructure;
using LHT.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;

// Tầng nghiệp vụ + hạ tầng (SQL Server, file, push)
builder.Services.AddApplication();
builder.Services.AddInfrastructure(config);

// Người dùng hiện tại, token, realtime
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();
builder.Services.AddSingleton<ITokenService, JwtTokenService>();
builder.Services.AddSingleton<PresenceTracker>();
builder.Services.AddSingleton<IRealtimeNotifier, RealtimeNotifier>();
builder.Services.AddSingleton<IUserIdProvider, SubUserIdProvider>();

// Hàng đợi & xử lý nhật ký API nền
builder.Services.AddSingleton<ApiLogQueue>();
builder.Services.AddSingleton<IApiLogQueue>(sp => sp.GetRequiredService<ApiLogQueue>());
builder.Services.AddHostedService<ApiLogProcessor>();

// Xác thực JWT (dùng cho cả REST và SignalR)
var jwtKey = config["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey)) throw new InvalidOperationException("Thiếu cấu hình Jwt:Key");
builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.MapInboundClaims = false;
        o.TokenValidationParameters = new TokenValidationParameters
        {
            ValidIssuer = config["Jwt:Issuer"],
            ValidAudience = config["Jwt:Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            NameClaimType = "name",
        };
        // SignalR gửi token qua query string ?access_token=
        o.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(token) && ctx.HttpContext.Request.Path.StartsWithSegments("/hubs"))
                    ctx.Token = token;
                return Task.CompletedTask;
            },
        };
    });

// Phân quyền động theo mã chức năng
builder.Services.AddSingleton<IAuthorizationPolicyProvider, PermissionPolicyProvider>();
builder.Services.AddSingleton<IAuthorizationHandler, PermissionHandler>();
builder.Services.AddAuthorization();

// App Flutter web chạy cổng khác khi dev → cho phép CORS
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
    p.SetIsOriginAllowed(_ => true).AllowAnyHeader().AllowAnyMethod().AllowCredentials()));

builder.Services.AddControllers()
    .ConfigureApiBehaviorOptions(o => o.InvalidModelStateResponseFactory = ctx =>
    {
        var errors = ctx.ModelState.Where(x => x.Value?.Errors.Count > 0)
            .ToDictionary(x => x.Key, x => x.Value!.Errors.First().ErrorMessage);
        return new Microsoft.AspNetCore.Mvc.UnprocessableEntityObjectResult(
            LHT.Application.Common.ApiResponse<object>.Fail("VALIDATION_ERROR", "Dữ liệu không hợp lệ", errors));
    });
builder.Services.AddSignalR();
builder.Services.AddOpenApi();
builder.Services.AddHealthChecks();

var app = builder.Build();

// Tự áp migration + seed phân quyền khi khởi động
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();
    await scope.ServiceProvider.GetRequiredService<PermissionSeeder>().SeedAsync();
}

app.UseMiddleware<ExceptionMiddleware>();
app.UseMiddleware<ApiLoggingMiddleware>();
app.UseCors();

if (app.Environment.IsDevelopment())
    app.MapOpenApi(); // /openapi/v1.json

// Bản build Flutter web (wwwroot) được phục vụ cùng cổng
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");
app.MapHub<ChatHub>("/hubs/chat");
app.MapHub<NotificationHub>("/hubs/notifications");
app.MapFallbackToFile("index.html"); // điều hướng của app web

app.Run();

/// <summary>SignalR dùng claim "sub" làm UserIdentifier.</summary>
public class SubUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) => connection.User?.FindFirst("sub")?.Value;
}
