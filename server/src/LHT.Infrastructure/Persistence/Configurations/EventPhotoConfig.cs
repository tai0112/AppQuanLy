using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class EventPhotoConfig : IEntityTypeConfiguration<EventPhoto>
{
    public void Configure(EntityTypeBuilder<EventPhoto> b)
    {
        b.HasOne<Event>().WithMany().HasForeignKey(x => x.EventId);
        b.HasOne<StoredFile>().WithMany().HasForeignKey(x => x.FileId);
        b.HasIndex(x => new { x.EventId, x.OccurrenceDate });
        b.HasIndex(x => x.EventItemId);
    }
}
