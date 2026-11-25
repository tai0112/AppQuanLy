using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ViTriGiaoDich : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "DiaDiem",
                table: "GiaoDich",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true,
                comment: "Địa điểm");

            migrationBuilder.AddColumn<double>(
                name: "KinhDo",
                table: "GiaoDich",
                type: "float",
                nullable: true,
                comment: "Kinh độ");

            migrationBuilder.AddColumn<double>(
                name: "ViDo",
                table: "GiaoDich",
                type: "float",
                nullable: true,
                comment: "Vĩ độ");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "DiaDiem",
                table: "GiaoDich");

            migrationBuilder.DropColumn(
                name: "KinhDo",
                table: "GiaoDich");

            migrationBuilder.DropColumn(
                name: "ViDo",
                table: "GiaoDich");
        }
    }
}
