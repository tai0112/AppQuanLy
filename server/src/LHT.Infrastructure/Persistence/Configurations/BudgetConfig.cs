using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class BudgetConfig : IEntityTypeConfiguration<Budget>
{
    public void Configure(EntityTypeBuilder<Budget> b)
    {
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.CurrencyCode).HasMaxLength(10);
    }
}
