using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class ConversationMemberConfig : IEntityTypeConfiguration<ConversationMember>
{
    public void Configure(EntityTypeBuilder<ConversationMember> b)
    {
        b.HasOne<Conversation>().WithMany().HasForeignKey(x => x.ConversationId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.MemberUserId);
        b.HasIndex(x => new { x.ConversationId, x.MemberUserId }).IsUnique().HasFilter(Cfg.NotDeleted);
        b.HasIndex(x => x.MemberUserId);
    }
}
