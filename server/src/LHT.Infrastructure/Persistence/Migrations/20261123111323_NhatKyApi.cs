using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class NhatKyApi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NhatKyApi",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Mã người dùng (nếu đã đăng nhập)"),
                    TenDangNhap = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true, comment: "Tên đăng nhập"),
                    PhuongThuc = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Phương thức HTTP: GET, POST, PUT, DELETE..."),
                    DuongDan = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false, comment: "Đường dẫn API"),
                    ThamSo = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Tham số truy vấn"),
                    MaTrangThai = table.Column<int>(type: "int", nullable: false, comment: "Mã trạng thái HTTP: 200, 400, 401, 500..."),
                    ThoiGianXuLyMs = table.Column<long>(type: "bigint", nullable: false, comment: "Thời gian xử lý tính bằng mili-giây"),
                    DiaChiIp = table.Column<string>(type: "nvarchar(64)", maxLength: 64, nullable: true, comment: "Địa chỉ IP client"),
                    TrinhDuyet = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Trình duyệt hoặc ứng dụng gọi API"),
                    DuLieuYeuCau = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Nội dung body gửi lên (đã che mật khẩu)"),
                    DuLieuTraVe = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Nội dung phản hồi hoặc thông điệp lỗi"),
                    ThongDiepLoi = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Chi tiết lỗi / Exception nếu có"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NhatKyApi", x => x.Id);
                },
                comment: "Nhật ký truy cập và gọi API của hệ thống");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyApi_DuongDan",
                table: "NhatKyApi",
                column: "DuongDan");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyApi_MaTrangThai",
                table: "NhatKyApi",
                column: "MaTrangThai");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyApi_NgayCapNhat",
                table: "NhatKyApi",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyApi_NgayTao",
                table: "NhatKyApi",
                column: "NgayTao");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyApi_NguoiDungId",
                table: "NhatKyApi",
                column: "NguoiDungId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NhatKyApi");
        }
    }
}
