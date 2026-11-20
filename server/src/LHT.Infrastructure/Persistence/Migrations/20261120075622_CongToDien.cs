using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class CongToDien : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<Guid>(
                name: "CongToId",
                table: "HoaDonDien",
                type: "uniqueidentifier",
                nullable: true,
                comment: "Công tơ (NULL = hoá đơn tổng EVN của cả nhà)");

            migrationBuilder.CreateTable(
                name: "CongTo",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên công tơ, vd Tầng 3"),
                    PhanLoai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=nhà dùng (khoản chi), 2=cho thuê (khoản thu)"),
                    TenNguoiThue = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true, comment: "Tên người thuê (khi cho thuê)"),
                    BangGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bảng giá áp dụng cho công tơ này"),
                    ChiSoBanDau = table.Column<int>(type: "int", nullable: false, comment: "Chỉ số lúc bắt đầu theo dõi"),
                    DanhMucId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Danh mục dùng khi tạo giao dịch (NULL = tự chọn theo loại)"),
                    TaiKhoanId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tài khoản dùng khi tạo giao dịch (NULL = tài khoản mặc định)"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    DaLuuTru = table.Column<bool>(type: "bit", nullable: false, comment: "Đã ngừng theo dõi"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CongTo", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CongTo_BangGiaDien_BangGiaId",
                        column: x => x.BangGiaId,
                        principalTable: "BangGiaDien",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_CongTo_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Công tơ điện (mỗi tầng/phòng một cái): dùng riêng hoặc cho thuê");

            migrationBuilder.CreateIndex(
                name: "IX_HoaDonDien_CongToId_Ky",
                table: "HoaDonDien",
                columns: new[] { "CongToId", "Ky" });

            migrationBuilder.CreateIndex(
                name: "IX_CongTo_BangGiaId",
                table: "CongTo",
                column: "BangGiaId");

            migrationBuilder.CreateIndex(
                name: "IX_CongTo_NguoiDungId_NgayCapNhat",
                table: "CongTo",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_CongTo_NguoiDungId_ThuTu",
                table: "CongTo",
                columns: new[] { "NguoiDungId", "ThuTu" });

            migrationBuilder.AddForeignKey(
                name: "FK_HoaDonDien_CongTo_CongToId",
                table: "HoaDonDien",
                column: "CongToId",
                principalTable: "CongTo",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_HoaDonDien_CongTo_CongToId",
                table: "HoaDonDien");

            migrationBuilder.DropTable(
                name: "CongTo");

            migrationBuilder.DropIndex(
                name: "IX_HoaDonDien_CongToId_Ky",
                table: "HoaDonDien");

            migrationBuilder.DropColumn(
                name: "CongToId",
                table: "HoaDonDien");
        }
    }
}
