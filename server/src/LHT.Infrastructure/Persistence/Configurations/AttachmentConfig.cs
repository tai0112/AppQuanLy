using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class AttachmentConfig : IEntityTypeConfiguration<Attachment>
{
    public void Configure(EntityTypeBuilder<Attachment> b)
    {
        b.HasOne(x => x.File).WithMany().HasForeignKey(x => x.FileId);
        b.HasIndex(x => new { x.OwnerType, x.OwnerId });
    }
}
