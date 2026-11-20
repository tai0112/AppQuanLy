using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ExchangeRateConfig : IEntityTypeConfiguration<ExchangeRate>
{
    public void Configure(EntityTypeBuilder<ExchangeRate> b)
    {
        b.Property(x => x.FromCode).HasMaxLength(10);
        b.Property(x => x.ToCode).HasMaxLength(10);
        b.Property(x => x.Rate).HasPrecision(28, 10);
        b.HasIndex(x => new { x.UserId, x.FromCode, x.ToCode, x.EffectiveDate }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
