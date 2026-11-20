namespace LHT.Infrastructure.Persistence;

// Cấu hình riêng từng bảng: độ dài cột, index, quan hệ.
// Index duy nhất có điều kiện "chưa xoá mềm" để cho phép tạo lại sau khi xoá.

internal static class Cfg
{
    public const string NotDeleted = "[NgayXoa] IS NULL";
}
