using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ReminderConfig : IEntityTypeConfiguration<Reminder>
{
    public void Configure(EntityTypeBuilder<Reminder> b)
    {
        b.Property(x => x.Title).HasMaxLength(200);
        b.Property(x => x.Icon).HasMaxLength(50);
        b.Property(x => x.Color).HasMaxLength(9);
        b.Property(x => x.Times).HasMaxLength(200);
        b.Property(x => x.Weekdays).HasMaxLength(20);
        b.Property(x => x.Dates).HasMaxLength(4000);
    }
}
