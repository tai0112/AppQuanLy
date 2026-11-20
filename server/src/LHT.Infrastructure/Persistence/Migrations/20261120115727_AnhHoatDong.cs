using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AnhHoatDong : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "HoatDongId",
                table: "AnhLichTrinh",
                type: "uniqueidentifier",
                nullable: true,
                comment: "Hoạt động trong lịch trình (NULL = ảnh chung của album)");

            migrationBuilder.CreateIndex(
                name: "IX_AnhLichTrinh_HoatDongId",
                table: "AnhLichTrinh",
                column: "HoatDongId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_AnhLichTrinh_HoatDongId",
                table: "AnhLichTrinh");

            migrationBuilder.DropColumn(
                name: "HoatDongId",
                table: "AnhLichTrinh");
        }
    }
}
