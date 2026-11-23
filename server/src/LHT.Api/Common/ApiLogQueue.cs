using System.Threading.Channels;
using LHT.Domain.Entities;
using LHT.Infrastructure.Persistence;

namespace LHT.Api.Common;

public interface IApiLogQueue
{
    void Queue(ApiLog log);
}

public class ApiLogQueue : IApiLogQueue
{
    private readonly Channel<ApiLog> _channel = Channel.CreateBounded<ApiLog>(new BoundedChannelOptions(10000)
    {
        FullMode = BoundedChannelFullMode.DropOldest,
        SingleReader = true,
    });

    public ChannelReader<ApiLog> Reader => _channel.Reader;

    public void Queue(ApiLog log)
    {
        _channel.Writer.TryWrite(log);
    }
}

public class ApiLogProcessor(ApiLogQueue queue, IServiceScopeFactory scopeFactory, ILogger<ApiLogProcessor> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var batch = new List<ApiLog>();

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                // Chờ ít nhất 1 phần tử
                if (await queue.Reader.WaitToReadAsync(stoppingToken))
                {
                    while (queue.Reader.TryRead(out var item))
                    {
                        batch.Add(item);
                        if (batch.Count >= 100) break;
                    }

                    if (batch.Count > 0)
                    {
                        using var scope = scopeFactory.CreateScope();
                        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                        db.ApiLogs.AddRange(batch);
                        await db.SaveChangesAsync(stoppingToken);
                        batch.Clear();
                    }
                }
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Lỗi khi ghi lô nhật ký API vào cơ sở dữ liệu");
                batch.Clear();
                await Task.Delay(1000, stoppingToken);
            }
        }
    }
}

