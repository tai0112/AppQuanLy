using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class UserRoleConfig : IEntityTypeConfiguration<UserRole>
{
    public void Configure(EntityTypeBuilder<UserRole> b)
    {
        b.HasOne<User>().WithMany().HasForeignKey(x => x.MemberUserId);
        b.HasOne<Role>().WithMany().HasForeignKey(x => x.RoleId);
        b.HasIndex(x => new { x.MemberUserId, x.RoleId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
