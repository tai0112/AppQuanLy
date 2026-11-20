using LHT.Application.Abstractions;
using LHT.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace LHT.Infrastructure;

public static class DependencyInjection
{
    /// <summary>Đăng ký DbContext (SQL Server), repository, unit of work.</summary>
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        var connectionString = config.GetConnectionString("Default")
            ?? throw new InvalidOperationException("Thiếu ConnectionStrings:Default trong cấu hình");

        services.AddSingleton(TimeProvider.System);
        services.AddScoped<AuditInterceptor>();
        services.AddDbContext<AppDbContext>((sp, options) =>
            options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure())
                   .AddInterceptors(sp.GetRequiredService<AuditInterceptor>()));

        services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());
        services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        services.AddSingleton<IFileStorage, Services.LocalFileStorage>();
        services.AddSingleton<IPushSender, Services.LoggingPushSender>();
        return services;
    }
}
