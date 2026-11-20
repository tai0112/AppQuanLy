using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class NotificationConfig : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> b)
    {
        b.Property(x => x.Title).HasMaxLength(200);
        b.HasIndex(x => new { x.UserId, x.ReadAt });
    }
}
