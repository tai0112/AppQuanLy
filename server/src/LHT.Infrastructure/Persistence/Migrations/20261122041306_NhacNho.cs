using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class NhacNho : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NhacNho",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    TieuDe = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Nội dung nhắc"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    BieuTuong = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Tên icon"),
                    MauSac = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu (hex)"),
                    CheDoLap = table.Column<byte>(type: "tinyint", nullable: false, comment: "Lặp lại: 1=hằng ngày, 2=theo thứ trong tuần, 3=từng ngày cụ thể"),
                    CacGio = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Các giờ nhắc trong ngày, vd 07:30,21:00"),
                    CacThu = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true, comment: "Các thứ nhắc khi lặp theo thứ: 1=Thứ 2 ... 7=Chủ nhật, vd 1,3,5"),
                    CacNgay = table.Column<string>(type: "nvarchar(4000)", maxLength: 4000, nullable: true, comment: "Các ngày nhắc khi chọn từng ngày, vd 2026-11-25,2026-11-28"),
                    DangBat = table.Column<bool>(type: "bit", nullable: false, comment: "Đang bật"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự sắp xếp"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NhacNho", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NhacNho_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Nhắc nhở do người dùng tự đặt (uống nước, uống thuốc...)");

            migrationBuilder.CreateIndex(
                name: "IX_NhacNho_NguoiDungId_NgayCapNhat",
                table: "NhacNho",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NhacNho");
        }
    }
}
