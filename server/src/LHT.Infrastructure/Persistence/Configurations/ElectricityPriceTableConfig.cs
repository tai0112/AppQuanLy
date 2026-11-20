using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ElectricityPriceTableConfig : IEntityTypeConfiguration<ElectricityPriceTable>
{
    public void Configure(EntityTypeBuilder<ElectricityPriceTable> b)
    {
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.VatPercent).HasPrecision(5, 2);
        b.HasMany(x => x.Tiers).WithOne().HasForeignKey(x => x.PriceTableId);
    }
}
