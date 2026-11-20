using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CurrencyConfig : IEntityTypeConfiguration<Currency>
{
    public void Configure(EntityTypeBuilder<Currency> b)
    {
        b.Property(x => x.Code).HasMaxLength(10);
        b.Property(x => x.Symbol).HasMaxLength(10);
        b.Property(x => x.Name).HasMaxLength(100);
        b.HasIndex(x => new { x.UserId, x.Code }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
