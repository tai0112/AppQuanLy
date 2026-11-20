using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class RoleOperationConfig : IEntityTypeConfiguration<RoleOperation>
{
    public void Configure(EntityTypeBuilder<RoleOperation> b)
    {
        b.HasOne<Role>().WithMany().HasForeignKey(x => x.RoleId);
        b.HasOne<Operation>().WithMany().HasForeignKey(x => x.OperationId);
        b.HasIndex(x => new { x.RoleId, x.OperationId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
