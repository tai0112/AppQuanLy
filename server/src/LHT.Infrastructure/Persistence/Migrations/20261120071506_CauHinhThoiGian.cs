using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CauHinhThoiGian : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<byte>(
                name: "Loai",
                table: "DanhMuc",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=chi, 2=thu, 3=lịch trình, 4=mẫu hoạt động trong ngày",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=chi, 2=thu, 3=lịch trình");

            migrationBuilder.AddColumn<string>(
                name: "CauHinhThoiGianJson",
                table: "CaiDat",
                type: "nvarchar(max)",
                nullable: true,
                comment: "Cấu hình thời gian (JSON): các mốc nhắc, nhắc mặc định, khung giờ timeline, bước làm tròn, thời lượng hoạt động mặc định");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CauHinhThoiGianJson",
                table: "CaiDat");

            migrationBuilder.AlterColumn<byte>(
                name: "Loai",
                table: "DanhMuc",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=chi, 2=thu, 3=lịch trình",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=chi, 2=thu, 3=lịch trình, 4=mẫu hoạt động trong ngày");
        }
    }
}
