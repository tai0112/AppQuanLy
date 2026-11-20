using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class OperationConfig : IEntityTypeConfiguration<Operation>
{
    public void Configure(EntityTypeBuilder<Operation> b)
    {
        b.Property(x => x.Code).HasMaxLength(100);
        b.HasOne<Module>().WithMany().HasForeignKey(x => x.ModuleId);
        b.HasOne<Operation>().WithMany().HasForeignKey(x => x.ParentId);
        b.HasIndex(x => x.Code).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
