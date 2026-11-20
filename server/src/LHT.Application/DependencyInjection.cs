using LHT.Application.Features.Auth;
using LHT.Application.Features.Files;
using LHT.Application.Features.Permissions;
using LHT.Application.Features.Social;
using LHT.Application.Features.Sync;
using Microsoft.Extensions.DependencyInjection;

namespace LHT.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddMemoryCache();
        services.AddScoped<IPermissionService, PermissionService>();
        services.AddScoped<AdminService>();
        services.AddScoped<PermissionSeeder>();
        services.AddScoped<AuthService>();
        services.AddScoped<SocialLookup>();
        services.AddScoped<NotificationService>();
        services.AddScoped<FriendService>();
        services.AddScoped<ModerationService>();
        services.AddScoped<LHT.Application.Features.AccountDeletion.AccountService>();
        services.AddScoped<ChatService>();
        services.AddScoped<PostService>();
        services.AddScoped<EventShareService>();
        services.AddScoped<SyncService>();
        services.AddScoped<FileService>();
        return services;
    }
}
