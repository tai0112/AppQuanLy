using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class AccountConfig : IEntityTypeConfiguration<Account>
{
    public void Configure(EntityTypeBuilder<Account> b)
    {
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.CurrencyCode).HasMaxLength(10);
        b.Property(x => x.Color).HasMaxLength(9);
        b.Property(x => x.Icon).HasMaxLength(50);
    }
}
