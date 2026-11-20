using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class EventItemConfig : IEntityTypeConfiguration<EventItem>
{
    public void Configure(EntityTypeBuilder<EventItem> b)
    {
        b.Property(x => x.Title).HasMaxLength(200);
        b.Property(x => x.Icon).HasMaxLength(50);
        b.HasOne<Event>().WithMany().HasForeignKey(x => x.EventId);
        b.HasIndex(x => new { x.EventId, x.OccurrenceDate, x.StartTime });
    }
}
