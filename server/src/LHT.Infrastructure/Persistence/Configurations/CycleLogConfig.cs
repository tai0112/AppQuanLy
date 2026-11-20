using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CycleLogConfig : IEntityTypeConfiguration<CycleLog>
{
    public void Configure(EntityTypeBuilder<CycleLog> b)
    {
        b.Property(x => x.Mood).HasMaxLength(50);
        b.HasIndex(x => new { x.UserId, x.Subject, x.Date }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
