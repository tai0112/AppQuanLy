using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ReportConfig : IEntityTypeConfiguration<Report>
{
    public void Configure(EntityTypeBuilder<Report> b)
    {
        b.HasOne<User>().WithMany().HasForeignKey(x => x.ReporterId);
        b.Property(x => x.Note).HasMaxLength(1000);
        b.HasIndex(x => new { x.Status, x.CreatedAt });
        b.HasIndex(x => new { x.ReporterId, x.TargetType, x.TargetId });
    }
}
