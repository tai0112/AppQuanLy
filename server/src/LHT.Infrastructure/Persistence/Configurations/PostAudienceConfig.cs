using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class PostAudienceConfig : IEntityTypeConfiguration<PostAudience>
{
    public void Configure(EntityTypeBuilder<PostAudience> b)
    {
        b.HasOne<Post>().WithMany().HasForeignKey(x => x.PostId);
        b.HasIndex(x => new { x.PostId, x.ViewerUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
        b.HasIndex(x => x.ViewerUserId);
    }
}
