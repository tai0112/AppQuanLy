using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ReactionConfig : IEntityTypeConfiguration<Reaction>
{
    public void Configure(EntityTypeBuilder<Reaction> b)
    {
        b.HasOne<User>().WithMany().HasForeignKey(x => x.ReactorUserId);
        b.HasIndex(x => new { x.TargetType, x.TargetId, x.ReactorUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
