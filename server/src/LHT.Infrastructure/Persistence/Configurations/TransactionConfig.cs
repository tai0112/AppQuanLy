using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class TransactionConfig : IEntityTypeConfiguration<Transaction>
{
    public void Configure(EntityTypeBuilder<Transaction> b)
    {
        b.Property(x => x.CurrencyCode).HasMaxLength(10);
        b.HasOne(x => x.Account).WithMany().HasForeignKey(x => x.AccountId);
        b.HasOne<Account>().WithMany().HasForeignKey(x => x.ToAccountId);
        b.HasOne(x => x.Category).WithMany().HasForeignKey(x => x.CategoryId);
        b.HasIndex(x => new { x.UserId, x.OccurredAt });
        b.HasIndex(x => new { x.UserId, x.CategoryId, x.OccurredAt });
        b.HasIndex(x => new { x.UserId, x.AccountId, x.OccurredAt });
        b.HasIndex(x => x.EventId);
    }
}
