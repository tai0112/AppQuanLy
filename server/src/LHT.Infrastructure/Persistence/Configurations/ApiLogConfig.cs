using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence.Configurations;

public class ApiLogConfig : IEntityTypeConfiguration<ApiLog>
{
    public void Configure(EntityTypeBuilder<ApiLog> b)
    {
        b.Property(x => x.Method).HasMaxLength(10).IsRequired();
        b.Property(x => x.Path).HasMaxLength(300).IsRequired();
        b.Property(x => x.IpAddress).HasMaxLength(64);
        b.Property(x => x.UserAgent).HasMaxLength(500);
        b.Property(x => x.Username).HasMaxLength(100);

        b.HasIndex(x => x.CreatedAt);
        b.HasIndex(x => x.StatusCode);
        b.HasIndex(x => x.Path);
        b.HasIndex(x => x.UserId);
    }
}

