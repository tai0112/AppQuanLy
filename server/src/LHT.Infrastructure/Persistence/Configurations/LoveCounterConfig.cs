using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class LoveCounterConfig : IEntityTypeConfiguration<LoveCounter>
{
    public void Configure(EntityTypeBuilder<LoveCounter> b)
    {
        b.Property(x => x.PartnerName).HasMaxLength(100);
        b.HasIndex(x => x.UserId).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
