using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ElectricityMeterConfig : IEntityTypeConfiguration<ElectricityMeter>
{
    public void Configure(EntityTypeBuilder<ElectricityMeter> b)
    {
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.TenantName).HasMaxLength(100);
        b.Property(x => x.Note).HasMaxLength(500);
        b.HasOne<ElectricityPriceTable>().WithMany().HasForeignKey(x => x.PriceTableId).OnDelete(DeleteBehavior.NoAction);
        b.HasIndex(x => new { x.UserId, x.SortOrder });
    }
}
