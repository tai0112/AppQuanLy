using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ElectricityBillConfig : IEntityTypeConfiguration<ElectricityBill>
{
    public void Configure(EntityTypeBuilder<ElectricityBill> b)
    {
        b.HasOne<ElectricityPriceTable>().WithMany().HasForeignKey(x => x.PriceTableId);
        b.HasOne<ElectricityMeter>().WithMany().HasForeignKey(x => x.MeterId).OnDelete(DeleteBehavior.NoAction);
        b.HasIndex(x => new { x.UserId, x.Period });
        b.HasIndex(x => new { x.MeterId, x.Period });
    }
}
