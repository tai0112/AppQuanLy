using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class RoleConfig : IEntityTypeConfiguration<Role>
{
    public void Configure(EntityTypeBuilder<Role> b)
    {
        b.Property(x => x.Code).HasMaxLength(50);
        b.HasIndex(x => x.Code).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
