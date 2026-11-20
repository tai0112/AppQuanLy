using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CyclePeriodConfig : IEntityTypeConfiguration<CyclePeriod>
{
    public void Configure(EntityTypeBuilder<CyclePeriod> b)
        => b.HasIndex(x => new { x.UserId, x.Subject, x.StartDate });
}
