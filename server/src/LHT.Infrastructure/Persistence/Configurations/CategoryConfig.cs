using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CategoryConfig : IEntityTypeConfiguration<Category>
{
    public void Configure(EntityTypeBuilder<Category> b)
    {
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.Color).HasMaxLength(9);
        b.Property(x => x.Icon).HasMaxLength(50);
        b.HasOne(x => x.Parent).WithMany().HasForeignKey(x => x.ParentId);
        b.HasIndex(x => new { x.UserId, x.Type, x.ParentId });
    }
}
