using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class EventConfig : IEntityTypeConfiguration<Event>
{
    public void Configure(EntityTypeBuilder<Event> b)
    {
        b.Property(x => x.Title).HasMaxLength(200);
        b.Property(x => x.Color).HasMaxLength(9);
        b.Property(x => x.CurrencyCode).HasMaxLength(10);
        b.HasOne<Plan>().WithMany().HasForeignKey(x => x.PlanId);
        b.HasIndex(x => new { x.UserId, x.StartAt });
        b.HasIndex(x => x.CategoryId);
    }
}
