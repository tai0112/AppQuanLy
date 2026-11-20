namespace LHT.Api.Hubs;

public static class HubGroups
{
    public static string User(Guid userId) => $"user:{userId}";
    public static string Conversation(Guid id) => $"conversation:{id}";
}
