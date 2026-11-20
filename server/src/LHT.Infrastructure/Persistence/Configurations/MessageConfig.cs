using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace LHT.Infrastructure.Persistence;

public class MessageConfig : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> b)
    {
        b.HasOne<Conversation>().WithMany().HasForeignKey(x => x.ConversationId);
        b.HasOne<User>().WithMany().HasForeignKey(x => x.SenderId);
        b.HasIndex(x => new { x.ConversationId, x.ServerReceivedAt });
    }
}
