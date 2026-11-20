using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class PlanMemberConfig : IEntityTypeConfiguration<PlanMember>
{
    public void Configure(EntityTypeBuilder<PlanMember> b)
    {
        b.HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.MemberUserId);
        b.HasIndex(x => new { x.PlanId, x.MemberUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
