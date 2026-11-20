using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ElectricityTierConfig : IEntityTypeConfiguration<ElectricityTier>
{
    public void Configure(EntityTypeBuilder<ElectricityTier> b)
        => b.HasIndex(x => new { x.PriceTableId, x.TierOrder }).IsUnique().HasFilter(Cfg.NotDeleted);
}
