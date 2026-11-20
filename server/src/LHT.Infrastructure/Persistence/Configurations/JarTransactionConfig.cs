using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class JarTransactionConfig : IEntityTypeConfiguration<JarTransaction>
{
    public void Configure(EntityTypeBuilder<JarTransaction> b)
    {
        b.HasOne(x => x.Jar).WithMany().HasForeignKey(x => x.JarId);
        b.HasIndex(x => new { x.JarId, x.OccurredAt });
    }
}
