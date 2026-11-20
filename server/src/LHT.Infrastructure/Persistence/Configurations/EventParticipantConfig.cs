using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class EventParticipantConfig : IEntityTypeConfiguration<EventParticipant>
{
    public void Configure(EntityTypeBuilder<EventParticipant> b)
    {
        b.HasOne<Event>().WithMany().HasForeignKey(x => x.EventId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.ParticipantUserId);
        b.HasIndex(x => new { x.EventId, x.ParticipantUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
