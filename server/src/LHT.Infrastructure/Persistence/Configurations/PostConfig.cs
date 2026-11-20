using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class PostConfig : IEntityTypeConfiguration<Post>
{
    public void Configure(EntityTypeBuilder<Post> b)
    {
        b.Property(x => x.Feeling).HasMaxLength(100);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.AuthorId);
        b.HasIndex(x => new { x.AuthorId, x.CreatedAt });
    }
}
