using System.ComponentModel;
using System.Linq.Expressions;
using System.Reflection;
using LHT.Domain.Common;
using LHT.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace LHT.Infrastructure.Persistence;

public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options), LHT.Application.Abstractions.IAppDbContext
{
    // Người dùng
    public DbSet<User> Users => Set<User>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Device> Devices => Set<Device>();

    // Tài chính
    public DbSet<Currency> Currencies => Set<Currency>();
    public DbSet<ExchangeRate> ExchangeRates => Set<ExchangeRate>();
    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<Category> Categories => Set<Category>();
    public DbSet<Transaction> Transactions => Set<Transaction>();
    public DbSet<RecurringRule> RecurringRules => Set<RecurringRule>();
    public DbSet<Budget> Budgets => Set<Budget>();
    public DbSet<SavingsJar> SavingsJars => Set<SavingsJar>();
    public DbSet<JarTransaction> JarTransactions => Set<JarTransaction>();

    // File
    public DbSet<StoredFile> StoredFiles => Set<StoredFile>();
    public DbSet<Attachment> Attachments => Set<Attachment>();

    // Tiện ích cá nhân
    public DbSet<ElectricityPriceTable> ElectricityPriceTables => Set<ElectricityPriceTable>();
    public DbSet<ElectricityTier> ElectricityTiers => Set<ElectricityTier>();
    public DbSet<ElectricityBill> ElectricityBills => Set<ElectricityBill>();
    public DbSet<ElectricityMeter> ElectricityMeters => Set<ElectricityMeter>();
    public DbSet<LoveCounter> LoveCounters => Set<LoveCounter>();
    public DbSet<CyclePeriod> CyclePeriods => Set<CyclePeriod>();
    public DbSet<CycleLog> CycleLogs => Set<CycleLog>();
    public DbSet<CycleSettings> CycleSettings => Set<CycleSettings>();
    public DbSet<AppSettings> AppSettings => Set<AppSettings>();
    public DbSet<Reminder> Reminders => Set<Reminder>();

    // Lịch trình
    public DbSet<Plan> Plans => Set<Plan>();
    public DbSet<PlanMember> PlanMembers => Set<PlanMember>();
    public DbSet<Event> Events => Set<Event>();
    public DbSet<EventPhoto> EventPhotos => Set<EventPhoto>();
    public DbSet<EventParticipant> EventParticipants => Set<EventParticipant>();
    public DbSet<EventItem> EventItems => Set<EventItem>();

    // Xã hội
    public DbSet<Friendship> Friendships => Set<Friendship>();
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMember> ConversationMembers => Set<ConversationMember>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<Post> Posts => Set<Post>();
    public DbSet<PostAudience> PostAudiences => Set<PostAudience>();
    public DbSet<PostTag> PostTags => Set<PostTag>();
    public DbSet<Comment> Comments => Set<Comment>();
    public DbSet<Reaction> Reactions => Set<Reaction>();
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Report> Reports => Set<Report>();

    // Phân quyền động
    public DbSet<LHT.Domain.Entities.Module> Modules => Set<LHT.Domain.Entities.Module>();
    public DbSet<Operation> Operations => Set<Operation>();
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<UserRole> UserRoles => Set<UserRole>();
    public DbSet<RoleOperation> RoleOperations => Set<RoleOperation>();

    /// <summary>Tên cột dạng văn bản dài → nvarchar(max).</summary>
    private static readonly HashSet<string> LongTextColumns =
        ["Content", "Note", "Description", "Body", "Bio", "RRule"];

    protected override void ConfigureConventions(ModelConfigurationBuilder builder)
    {
        // Tiền: decimal(19,4). Chuỗi mặc định nvarchar(500).
        builder.Properties<decimal>().HavePrecision(19, 4);
        builder.Properties<decimal?>().HavePrecision(19, 4);
        builder.Properties<string>().HaveMaxLength(500);
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);

        foreach (var entityType in modelBuilder.Model.GetEntityTypes())
        {
            var clr = entityType.ClrType;
            if (!typeof(BaseEntity).IsAssignableFrom(clr)) continue;
            var entity = modelBuilder.Entity(clr);

            // Id do app sinh (UUID v7), DB không tự sinh.
            entity.Property(nameof(BaseEntity.Id)).ValueGeneratedNever();

            // Tên bảng/cột tiếng Việt không dấu + mô tả tiếng Việt có dấu → MS_Description.
            var tableDesc = clr.GetCustomAttribute<DescriptionAttribute>()?.Description;
            entity.ToTable(DbNames.Table(clr), t => { if (tableDesc is not null) t.HasComment(tableDesc); });
            foreach (var prop in entityType.GetProperties())
            {
                prop.SetColumnName(DbNames.Column(clr, prop.Name));
                var desc = prop.PropertyInfo?.GetCustomAttribute<DescriptionAttribute>()?.Description;
                if (desc is not null) prop.SetComment(desc);

                if (prop.ClrType == typeof(string) &&
                    (prop.Name.EndsWith("Json") || LongTextColumns.Contains(prop.Name)))
                    prop.SetMaxLength(null);
            }

            // Lọc bỏ bản ghi đã xoá mềm khỏi mọi truy vấn.
            entity.HasQueryFilter(SoftDeleteFilter(clr));

            // Bản ghi thuộc người dùng: FK tới Users + index phục vụ đồng bộ (pull theo UpdatedAt).
            if (typeof(OwnedEntity).IsAssignableFrom(clr))
            {
                entity.HasOne(typeof(User)).WithMany().HasForeignKey(nameof(OwnedEntity.UserId));
                entity.HasIndex(nameof(OwnedEntity.UserId), nameof(BaseEntity.UpdatedAt));
            }
            else
            {
                entity.HasIndex(nameof(BaseEntity.UpdatedAt));
            }
        }

        // Không xoá dây chuyền: dùng xoá mềm, đồng thời tránh lỗi "multiple cascade paths" của SQL Server.
        foreach (var fk in modelBuilder.Model.GetEntityTypes().SelectMany(e => e.GetForeignKeys()))
            fk.DeleteBehavior = DeleteBehavior.Restrict;
    }

    private static LambdaExpression SoftDeleteFilter(Type type)
    {
        var p = Expression.Parameter(type, "e");
        var body = Expression.Equal(
            Expression.Property(p, nameof(ISoftDelete.DeletedAt)),
            Expression.Constant(null, typeof(DateTimeOffset?)));
        return Expression.Lambda(body, p);
    }
}
