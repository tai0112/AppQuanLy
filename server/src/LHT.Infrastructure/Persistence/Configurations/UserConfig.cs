using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class UserConfig : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> b)
    {
        b.Property(x => x.Email).HasMaxLength(256);
        b.Property(x => x.Username).HasMaxLength(50);
        b.Property(x => x.DisplayName).HasMaxLength(100);
        b.HasIndex(x => x.Email).IsUnique().HasFilter(Cfg.NotDeleted);
        b.HasIndex(x => x.Username).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
