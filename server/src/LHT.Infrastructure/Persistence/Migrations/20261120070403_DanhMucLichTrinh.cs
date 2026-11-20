using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class DanhMucLichTrinh : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<byte>(
                name: "PhanLoai",
                table: "LichTrinh",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=đi chơi, 2=công việc, 99=khác (cũ, nay dùng DanhMucId)",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=đi chơi, 2=công việc, 99=khác");

            migrationBuilder.AddColumn<Guid>(
                name: "DanhMucId",
                table: "LichTrinh",
                type: "uniqueidentifier",
                nullable: true,
                comment: "Danh mục lịch trình do người dùng cấu hình (DanhMuc loại 3)");

            migrationBuilder.AlterColumn<byte>(
                name: "Loai",
                table: "DanhMuc",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=chi, 2=thu, 3=lịch trình",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=chi, 2=thu");

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinh_DanhMucId",
                table: "LichTrinh",
                column: "DanhMucId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_LichTrinh_DanhMucId",
                table: "LichTrinh");

            migrationBuilder.DropColumn(
                name: "DanhMucId",
                table: "LichTrinh");

            migrationBuilder.AlterColumn<byte>(
                name: "PhanLoai",
                table: "LichTrinh",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=đi chơi, 2=công việc, 99=khác",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=đi chơi, 2=công việc, 99=khác (cũ, nay dùng DanhMucId)");

            migrationBuilder.AlterColumn<byte>(
                name: "Loai",
                table: "DanhMuc",
                type: "tinyint",
                nullable: false,
                comment: "Loại: 1=chi, 2=thu",
                oldClrType: typeof(byte),
                oldType: "tinyint",
                oldComment: "Loại: 1=chi, 2=thu, 3=lịch trình");
        }
    }
}
