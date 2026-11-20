using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class KhoaTaiKhoan : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "BiKhoa",
                table: "NguoiDung",
                type: "bit",
                nullable: false,
                defaultValue: false,
                comment: "Tài khoản bị quản trị viên khoá (không đăng nhập được)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BiKhoa",
                table: "NguoiDung");
        }
    }
}
