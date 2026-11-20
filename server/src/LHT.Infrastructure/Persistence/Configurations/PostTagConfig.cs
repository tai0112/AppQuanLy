using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class PostTagConfig : IEntityTypeConfiguration<PostTag>
{
    public void Configure(EntityTypeBuilder<PostTag> b)
    {
        b.HasOne<Post>().WithMany().HasForeignKey(x => x.PostId);
        b.HasIndex(x => new { x.PostId, x.TaggedUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
    }
}
