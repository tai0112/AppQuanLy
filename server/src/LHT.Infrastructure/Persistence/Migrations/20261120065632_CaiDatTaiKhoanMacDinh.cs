using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CaiDatTaiKhoanMacDinh : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "NhoTaiKhoanLanTruoc",
                table: "CaiDat",
                type: "bit",
                nullable: false,
                defaultValue: false,
                comment: "Tự chọn tài khoản đã dùng ở giao dịch trước");

            migrationBuilder.AddColumn<Guid>(
                name: "TaiKhoanMacDinhId",
                table: "CaiDat",
                type: "uniqueidentifier",
                nullable: true,
                comment: "Tài khoản/ví mặc định khi thêm giao dịch (NULL = tài khoản đầu tiên)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "NhoTaiKhoanLanTruoc",
                table: "CaiDat");

            migrationBuilder.DropColumn(
                name: "TaiKhoanMacDinhId",
                table: "CaiDat");
        }
    }
}
