using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CapDoi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "CapDoiTu",
                table: "BanBe",
                type: "datetimeoffset",
                nullable: true,
                comment: "Thời điểm hai người xác nhận là người yêu");

            migrationBuilder.AddColumn<Guid>(
                name: "NguoiMoiCapDoiId",
                table: "BanBe",
                type: "uniqueidentifier",
                nullable: true,
                comment: "Người gửi lời mời làm người yêu");

            migrationBuilder.AddColumn<byte>(
                name: "TrangThaiCapDoi",
                table: "BanBe",
                type: "tinyint",
                nullable: true,
                comment: "Cặp đôi: NULL=không, 1=đang chờ xác nhận, 2=đã là người yêu");

            migrationBuilder.CreateIndex(
                name: "IX_BanBe_TrangThaiCapDoi",
                table: "BanBe",
                column: "TrangThaiCapDoi",
                filter: "[TrangThaiCapDoi] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_BanBe_TrangThaiCapDoi",
                table: "BanBe");

            migrationBuilder.DropColumn(
                name: "CapDoiTu",
                table: "BanBe");

            migrationBuilder.DropColumn(
                name: "NguoiMoiCapDoiId",
                table: "BanBe");

            migrationBuilder.DropColumn(
                name: "TrangThaiCapDoi",
                table: "BanBe");
        }
    }
}
