using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class KiemDuyetNoiDung : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "DongYDieuKhoanLuc",
                table: "NguoiDung",
                type: "datetimeoffset",
                nullable: true,
                comment: "Thời điểm đồng ý Điều khoản sử dụng & Chính sách quyền riêng tư");

            migrationBuilder.CreateTable(
                name: "BaoCaoViPham",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NguoiBaoCaoId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người gửi báo cáo"),
                    LoaiDoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại đối tượng: 1 bài viết, 2 bình luận, 3 người dùng, 4 tin nhắn"),
                    DoiTuongId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Id đối tượng bị báo cáo"),
                    NguoiBiBaoCaoId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Người bị báo cáo (chủ nội dung)"),
                    LyDo = table.Column<byte>(type: "tinyint", nullable: false, comment: "Lý do: 1 spam, 2 quấy rối, 3 tình dục, 4 bạo lực, 5 thù ghét, 6 lừa đảo, 99 khác"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Mô tả thêm của người báo cáo"),
                    TrangThai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Trạng thái: 1 chờ xử lý, 2 đã gỡ nội dung, 3 bỏ qua"),
                    XuLyLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xử lý"),
                    NguoiXuLyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Quản trị viên xử lý"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BaoCaoViPham", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BaoCaoViPham_NguoiDung_NguoiBaoCaoId",
                        column: x => x.NguoiBaoCaoId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Báo cáo nội dung / người dùng vi phạm (yêu cầu của App Store với nội dung do người dùng tạo)");

            migrationBuilder.CreateIndex(
                name: "IX_BaoCaoViPham_NgayCapNhat",
                table: "BaoCaoViPham",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_BaoCaoViPham_NguoiBaoCaoId_LoaiDoiTuong_DoiTuongId",
                table: "BaoCaoViPham",
                columns: new[] { "NguoiBaoCaoId", "LoaiDoiTuong", "DoiTuongId" });

            migrationBuilder.CreateIndex(
                name: "IX_BaoCaoViPham_TrangThai_NgayTao",
                table: "BaoCaoViPham",
                columns: new[] { "TrangThai", "NgayTao" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "BaoCaoViPham");

            migrationBuilder.DropColumn(
                name: "DongYDieuKhoanLuc",
                table: "NguoiDung");
        }
    }
}
