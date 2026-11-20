using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ModuleConfig : IEntityTypeConfiguration<Module>
{
    public void Configure(EntityTypeBuilder<Module> b)
    {
        b.Property(x => x.Code).HasMaxLength(100);
        b.HasIndex(x => x.Code).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
