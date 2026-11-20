using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class LichTrinhChiTiet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "LichTrinhChiTiet",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    LichTrinhId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Lịch trình"),
                    NgayLanLap = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày của hoạt động; NULL = áp dụng cho mọi lần lặp"),
                    GioBatDau = table.Column<TimeOnly>(type: "time", nullable: false, comment: "Giờ bắt đầu"),
                    GioKetThuc = table.Column<TimeOnly>(type: "time", nullable: true, comment: "Giờ kết thúc"),
                    TieuDe = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Tên hoạt động, vd Ăn sáng, Tham quan"),
                    DiaDiem = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Địa điểm"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    ChiPhi = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: true, comment: "Chi phí dự kiến"),
                    DaXong = table.Column<bool>(type: "bit", nullable: false, comment: "Đã hoàn thành"),
                    BieuTuong = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Biểu tượng"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    NguoiThemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người thêm"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LichTrinhChiTiet", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LichTrinhChiTiet_LichTrinh_LichTrinhId",
                        column: x => x.LichTrinhId,
                        principalTable: "LichTrinh",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Hoạt động theo giờ trong lịch trình (timeline trong ngày)");

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinhChiTiet_LichTrinhId_NgayLanLap_GioBatDau",
                table: "LichTrinhChiTiet",
                columns: new[] { "LichTrinhId", "NgayLanLap", "GioBatDau" });

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinhChiTiet_NgayCapNhat",
                table: "LichTrinhChiTiet",
                column: "NgayCapNhat");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "LichTrinhChiTiet");
        }
    }
}
