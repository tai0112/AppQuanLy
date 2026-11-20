using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class CommentConfig : IEntityTypeConfiguration<Comment>
{
    public void Configure(EntityTypeBuilder<Comment> b)
    {
        b.HasOne<Post>().WithMany().HasForeignKey(x => x.PostId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.AuthorId);
        b.HasOne<Comment>().WithMany().HasForeignKey(x => x.ParentId);
        b.HasIndex(x => new { x.PostId, x.CreatedAt });
    }
}
