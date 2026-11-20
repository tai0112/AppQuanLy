using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CycleSettingsConfig : IEntityTypeConfiguration<CycleSettings>
{
    public void Configure(EntityTypeBuilder<CycleSettings> b)
        => b.HasIndex(x => new { x.UserId, x.Subject }).IsUnique().HasFilter(Cfg.NotDeleted);
}
