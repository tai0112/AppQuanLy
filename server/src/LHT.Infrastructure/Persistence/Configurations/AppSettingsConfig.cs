using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class AppSettingsConfig : IEntityTypeConfiguration<AppSettings>
{
    public void Configure(EntityTypeBuilder<AppSettings> b)
    {
        b.Property(x => x.Theme).HasMaxLength(20);
        b.Property(x => x.PrimaryColor).HasMaxLength(9);
        b.Property(x => x.BaseCurrencyCode).HasMaxLength(10);
        b.HasIndex(x => x.UserId).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
