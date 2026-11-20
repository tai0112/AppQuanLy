using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class FriendshipConfig : IEntityTypeConfiguration<Friendship>
{
    public void Configure(EntityTypeBuilder<Friendship> b)
    {
        b.HasOne<User>().WithMany().HasForeignKey(x => x.RequesterId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.AddresseeId);
        b.HasIndex(x => new { x.RequesterId, x.AddresseeId }).IsUnique().HasFilter(Cfg.NotDeleted);
        b.HasIndex(x => new { x.AddresseeId, x.Status });
        b.HasIndex(x => x.CoupleStatus).HasFilter("[TrangThaiCapDoi] IS NOT NULL");
    }
}
