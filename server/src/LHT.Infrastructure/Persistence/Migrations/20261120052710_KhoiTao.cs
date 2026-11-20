using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace LHT.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class KhoiTao : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "HoiThoai",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=1-1, 2=nhóm"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true, comment: "Tên nhóm"),
                    AnhDaiDienId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh nhóm (StoredFiles.Id)"),
                    NguoiTaoId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người tạo"),
                    TinNhanCuoiId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tin nhắn cuối (để sắp xếp danh sách)"),
                    TinNhanCuoiLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm tin nhắn cuối"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HoiThoai", x => x.Id);
                },
                comment: "Hội thoại chat");

            migrationBuilder.CreateTable(
                name: "NguoiDung",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Email = table.Column<string>(type: "nvarchar(256)", maxLength: 256, nullable: false, comment: "Email đăng nhập (duy nhất)"),
                    TenDangNhap = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false, comment: "Tên người dùng để tìm kiếm, kết bạn (duy nhất)"),
                    MatKhauBam = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Mật khẩu đã băm"),
                    TenHienThi = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên hiển thị"),
                    AnhDaiDienId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh đại diện (StoredFiles.Id)"),
                    GioiThieu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Giới thiệu ngắn"),
                    NgaySinh = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày sinh"),
                    HoatDongLanCuoi = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Lần hoạt động gần nhất"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NguoiDung", x => x.Id);
                },
                comment: "Người dùng");

            migrationBuilder.CreateTable(
                name: "PhanHe",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ma = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Mã phân hệ, vd QUAN_TRI"),
                    Ten = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Tên phân hệ"),
                    BieuTuong = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Tên icon"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    HienMenu = table.Column<bool>(type: "bit", nullable: false, comment: "Hiện trên menu"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PhanHe", x => x.Id);
                },
                comment: "Phân hệ (nhóm chức năng)");

            migrationBuilder.CreateTable(
                name: "VaiTro",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ma = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false, comment: "Mã vai trò, vd ADMIN, USER"),
                    Ten = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Tên vai trò"),
                    MoTa = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Mô tả"),
                    DangBat = table.Column<bool>(type: "bit", nullable: false, comment: "Đang bật"),
                    LaHeThong = table.Column<bool>(type: "bit", nullable: false, comment: "Vai trò hệ thống (không cho xoá)"),
                    MacDinh = table.Column<bool>(type: "bit", nullable: false, comment: "Tự gán cho người dùng mới đăng ký"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VaiTro", x => x.Id);
                },
                comment: "Vai trò");

            migrationBuilder.CreateTable(
                name: "BaiViet",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    TacGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Tác giả"),
                    NoiDung = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Nội dung"),
                    QuyenXem = table.Column<byte>(type: "tinyint", nullable: false, comment: "Quyền xem: 1=bạn bè, 2=chỉ mình tôi, 3=chọn người"),
                    LichTrinhId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Gắn lịch trình"),
                    HuTietKiemId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Gắn hũ tiết kiệm"),
                    DiaDiem = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Địa điểm"),
                    CamXuc = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: true, comment: "Cảm xúc / trạng thái"),
                    SoCamXuc = table.Column<int>(type: "int", nullable: false, comment: "Số cảm xúc (đếm sẵn)"),
                    SoBinhLuan = table.Column<int>(type: "int", nullable: false, comment: "Số bình luận (đếm sẵn)"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BaiViet", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BaiViet_NguoiDung_TacGiaId",
                        column: x => x.TacGiaId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Bài viết");

            migrationBuilder.CreateTable(
                name: "BanBe",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NguoiMoiId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người gửi lời mời"),
                    NguoiDuocMoiId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người nhận lời mời"),
                    TrangThai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Trạng thái: 1=chờ, 2=bạn bè, 3=chặn"),
                    ChapNhanLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm chấp nhận"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BanBe", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BanBe_NguoiDung_NguoiDuocMoiId",
                        column: x => x.NguoiDuocMoiId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BanBe_NguoiDung_NguoiMoiId",
                        column: x => x.NguoiMoiId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Quan hệ bạn bè / lời mời kết bạn");

            migrationBuilder.CreateTable(
                name: "BangGiaDien",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên bảng giá, vd EVN sinh hoạt 2025"),
                    ThueVat = table.Column<decimal>(type: "decimal(5,2)", precision: 5, scale: 2, nullable: false, comment: "Thuế VAT (%)"),
                    PhiCoDinh = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Phí cố định mỗi kỳ"),
                    MacDinh = table.Column<bool>(type: "bit", nullable: false, comment: "Bảng giá mặc định"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BangGiaDien", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BangGiaDien_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Bảng giá điện bậc thang");

            migrationBuilder.CreateTable(
                name: "CaiDat",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BoCucMenuJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Bố cục menu, tiện ích trang chủ (JSON)"),
                    GiaoDien = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: false, comment: "Giao diện: system/light/dark"),
                    MauChuDao = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu chủ đạo (hex)"),
                    MaTienChinh = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ chính"),
                    NgayBatDauThang = table.Column<byte>(type: "tinyint", nullable: false, comment: "Ngày bắt đầu tháng tài chính (1-28)"),
                    NgayDauTuan = table.Column<byte>(type: "tinyint", nullable: false, comment: "Ngày đầu tuần: 1=Thứ hai, 7=Chủ nhật"),
                    ThongBaoJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Cấu hình thông báo (JSON)"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CaiDat", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CaiDat_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Cài đặt app của người dùng");

            migrationBuilder.CreateTable(
                name: "CamXuc",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    LoaiDoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Đối tượng: 1=bài viết, 2=bình luận"),
                    DoiTuongId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Id bài viết / bình luận"),
                    NguoiTuongTacId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người thả cảm xúc"),
                    PhanLoai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=like, 2=tim, 3=haha, 4=wow, 5=buồn, 6=giận"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CamXuc", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CamXuc_NguoiDung_NguoiTuongTacId",
                        column: x => x.NguoiTuongTacId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Cảm xúc (like, tim...)");

            migrationBuilder.CreateTable(
                name: "CauHinhChuKy",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    DoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Theo dõi cho: 1=bản thân, 2=người yêu"),
                    SoNgayChuKy = table.Column<int>(type: "int", nullable: false, comment: "Độ dài chu kỳ mặc định (ngày)"),
                    SoNgayHanhKinh = table.Column<int>(type: "int", nullable: false, comment: "Số ngày hành kinh mặc định"),
                    SoNgayHoangThe = table.Column<int>(type: "int", nullable: false, comment: "Pha hoàng thể (ngày từ rụng trứng tới kỳ sau)"),
                    SoNgayThuThaiTruoc = table.Column<int>(type: "int", nullable: false, comment: "Số ngày dễ thụ thai trước rụng trứng"),
                    SoNgayThuThaiSau = table.Column<int>(type: "int", nullable: false, comment: "Số ngày dễ thụ thai sau rụng trứng"),
                    NhacNhoJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Cấu hình nhắc nhở (JSON)"),
                    ChoPhepDongBo = table.Column<bool>(type: "bit", nullable: false, comment: "Cho phép đồng bộ dữ liệu chu kỳ lên server"),
                    ChiaSeNguoiAy = table.Column<bool>(type: "bit", nullable: false, comment: "Chia sẻ cho người yêu xem"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_CauHinhChuKy", x => x.Id);
                    table.ForeignKey(
                        name: "FK_CauHinhChuKy_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Cấu hình theo dõi chu kỳ");

            migrationBuilder.CreateTable(
                name: "DanhMuc",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên danh mục"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=chi, 2=thu"),
                    DanhMucChaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Danh mục cha, NULL = danh mục cấp 1"),
                    BieuTuong = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Tên icon"),
                    MauSac = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu (hex)"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự sắp xếp"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DanhMuc", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DanhMuc_DanhMuc_DanhMucChaId",
                        column: x => x.DanhMucChaId,
                        principalTable: "DanhMuc",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_DanhMuc_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Danh mục thu/chi (2 cấp)");

            migrationBuilder.CreateTable(
                name: "DemNgayYeu",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NgayBatDau = table.Column<DateOnly>(type: "date", nullable: false, comment: "Ngày bắt đầu yêu"),
                    TenNguoiAy = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên người ấy"),
                    SinhNhatNguoiAy = table.Column<DateOnly>(type: "date", nullable: true, comment: "Sinh nhật người ấy"),
                    NguoiAyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tài khoản người ấy trong app (nếu có)"),
                    AnhCuaToiId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh của tôi (StoredFiles.Id)"),
                    AnhNguoiAyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh người ấy (StoredFiles.Id)"),
                    NhacTruocSoNgay = table.Column<int>(type: "int", nullable: false, comment: "Nhắc trước mốc bao nhiêu ngày"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DemNgayYeu", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DemNgayYeu_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Đếm ngày yêu");

            migrationBuilder.CreateTable(
                name: "DinhMuc",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên định mức"),
                    PhamVi = table.Column<byte>(type: "tinyint", nullable: false, comment: "Phạm vi: 1=tổng, 2=danh mục, 3=tài khoản"),
                    DoiTuongApDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Id danh mục/tài khoản tương ứng phạm vi"),
                    Ky = table.Column<byte>(type: "tinyint", nullable: false, comment: "Chu kỳ: 1=ngày, 2=tuần, 3=tháng, 4=năm"),
                    HanMuc = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Hạn mức"),
                    MaTienTe = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ của hạn mức"),
                    NguongCanhBao = table.Column<byte>(type: "tinyint", nullable: false, comment: "Ngưỡng cảnh báo sắp vượt (%), mặc định 80"),
                    DangBat = table.Column<bool>(type: "bit", nullable: false, comment: "Đang bật"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DinhMuc", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DinhMuc_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Định mức chi tiêu");

            migrationBuilder.CreateTable(
                name: "GiaoDichDinhKy",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Tên quy tắc"),
                    MauJson = table.Column<string>(type: "nvarchar(max)", nullable: false, comment: "Mẫu giao dịch (JSON)"),
                    QuyTacLap = table.Column<string>(type: "nvarchar(max)", nullable: false, comment: "Quy tắc lặp theo chuẩn RRULE (RFC 5545)"),
                    LanChayTiepTheo = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Lần chạy kế tiếp"),
                    DangBat = table.Column<bool>(type: "bit", nullable: false, comment: "Đang bật"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GiaoDichDinhKy", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GiaoDichDinhKy_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Giao dịch định kỳ (tiền nhà, lương...)");

            migrationBuilder.CreateTable(
                name: "HuTietKiem",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên hũ"),
                    BieuTuong = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Tên icon"),
                    MauSac = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu (hex)"),
                    SoTienMucTieu = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Số tiền mục tiêu"),
                    MaTienTe = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ"),
                    HanHoanThanh = table.Column<DateOnly>(type: "date", nullable: true, comment: "Hạn hoàn thành"),
                    AnhBiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh bìa (StoredFiles.Id)"),
                    DaDong = table.Column<bool>(type: "bit", nullable: false, comment: "Đã hoàn thành / đóng hũ"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HuTietKiem", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HuTietKiem_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Hũ tiết kiệm");

            migrationBuilder.CreateTable(
                name: "KeHoach",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    TieuDe = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Tên kế hoạch"),
                    MoTa = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Mô tả"),
                    AnhBiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh bìa (StoredFiles.Id)"),
                    NgayBatDau = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày bắt đầu"),
                    NgayKetThuc = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày kết thúc"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KeHoach", x => x.Id);
                    table.ForeignKey(
                        name: "FK_KeHoach_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Kế hoạch chung (vd chuyến du lịch) gồm nhiều lịch trình");

            migrationBuilder.CreateTable(
                name: "KyKinh",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    DoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Theo dõi cho: 1=bản thân, 2=người yêu"),
                    NgayBatDau = table.Column<DateOnly>(type: "date", nullable: false, comment: "Ngày bắt đầu hành kinh"),
                    NgayKetThuc = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày kết thúc hành kinh"),
                    LuongMau = table.Column<byte>(type: "tinyint", nullable: true, comment: "Lượng máu: 1=ít, 2=vừa, 3=nhiều"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_KyKinh", x => x.Id);
                    table.ForeignKey(
                        name: "FK_KyKinh_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Kỳ kinh nguyệt");

            migrationBuilder.CreateTable(
                name: "MaLamMoi",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    MaBam = table.Column<string>(type: "nvarchar(128)", maxLength: 128, nullable: false, comment: "Giá trị token đã băm"),
                    HetHanLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm hết hạn"),
                    ThuHoiLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm bị thu hồi"),
                    ThietBiId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Thiết bị sử dụng token"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_MaLamMoi", x => x.Id);
                    table.ForeignKey(
                        name: "FK_MaLamMoi_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Refresh token để cấp lại access token");

            migrationBuilder.CreateTable(
                name: "NhatKyChuKy",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    DoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Theo dõi cho: 1=bản thân, 2=người yêu"),
                    Ngay = table.Column<DateOnly>(type: "date", nullable: false, comment: "Ngày ghi"),
                    TrieuChungJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Triệu chứng (JSON mảng mã)"),
                    TamTrang = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Tâm trạng"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NhatKyChuKy", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NhatKyChuKy_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Nhật ký triệu chứng hằng ngày");

            migrationBuilder.CreateTable(
                name: "TaiKhoan",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên tài khoản, vd Tiền mặt, Vietcombank"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=tiền mặt, 2=ngân hàng, 3=ví điện tử, 4=thẻ tín dụng, 99=khác"),
                    BieuTuong = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true, comment: "Tên icon"),
                    MauSac = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu (hex, vd #FF8800)"),
                    MaTienTe = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ của tài khoản"),
                    SoDuBanDau = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Số dư ban đầu"),
                    TinhVaoTong = table.Column<bool>(type: "bit", nullable: false, comment: "Có tính vào tổng tài sản không"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự sắp xếp"),
                    DaLuuTru = table.Column<bool>(type: "bit", nullable: false, comment: "Đã lưu trữ (ẩn khỏi danh sách)"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TaiKhoan", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TaiKhoan_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Tài khoản / ví tiền");

            migrationBuilder.CreateTable(
                name: "TepTin",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    DuongDan = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Đường dẫn lưu trữ tương đối"),
                    DuongDanThuNho = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Đường dẫn ảnh thu nhỏ"),
                    TenGoc = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Tên file gốc"),
                    KieuFile = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Kiểu MIME, vd image/jpeg"),
                    DungLuong = table.Column<long>(type: "bigint", nullable: false, comment: "Dung lượng (byte)"),
                    ChieuRong = table.Column<int>(type: "int", nullable: true, comment: "Chiều rộng ảnh (px)"),
                    ChieuCao = table.Column<int>(type: "int", nullable: true, comment: "Chiều cao ảnh (px)"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TepTin", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TepTin_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "File đã upload lên server (ảnh)");

            migrationBuilder.CreateTable(
                name: "ThanhVienHoiThoai",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    HoiThoaiId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Hội thoại"),
                    ThanhVienId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Thành viên"),
                    VaiTro = table.Column<byte>(type: "tinyint", nullable: false, comment: "Vai trò: 1=chủ, 2=thành viên"),
                    DaDocDenId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tin nhắn đã đọc gần nhất"),
                    DaNhanDenId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tin nhắn đã nhận gần nhất"),
                    TatThongBao = table.Column<bool>(type: "bit", nullable: false, comment: "Tắt thông báo"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ThanhVienHoiThoai", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ThanhVienHoiThoai_HoiThoai_HoiThoaiId",
                        column: x => x.HoiThoaiId,
                        principalTable: "HoiThoai",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ThanhVienHoiThoai_NguoiDung_ThanhVienId",
                        column: x => x.ThanhVienId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Thành viên hội thoại");

            migrationBuilder.CreateTable(
                name: "ThietBi",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NenTang = table.Column<byte>(type: "tinyint", nullable: false, comment: "Nền tảng: 1=iOS, 2=Android"),
                    FcmToken = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "FCM token để gửi push"),
                    Ten = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Tên thiết bị"),
                    PhienBanApp = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Phiên bản app"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ThietBi", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ThietBi_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Thiết bị đăng nhập - nhận thông báo đẩy");

            migrationBuilder.CreateTable(
                name: "ThongBao",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại thông báo"),
                    NguoiTacDongId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Người gây ra thông báo"),
                    TieuDe = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Tiêu đề"),
                    NoiDung = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Nội dung"),
                    DuLieuJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Dữ liệu điều hướng (JSON)"),
                    DaDocLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm đã đọc"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ThongBao", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ThongBao_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Thông báo trong app");

            migrationBuilder.CreateTable(
                name: "TienTe",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Ma = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã ISO 4217, vd VND, USD"),
                    Ten = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Tên tiền tệ"),
                    KyHieu = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Ký hiệu, vd ₫, $"),
                    SoThapPhan = table.Column<byte>(type: "tinyint", nullable: false, comment: "Số chữ số thập phân hiển thị (VND = 0)"),
                    ViTriKyHieu = table.Column<byte>(type: "tinyint", nullable: false, comment: "Vị trí ký hiệu: 1=sau số, 2=trước số"),
                    LaTienChinh = table.Column<bool>(type: "bit", nullable: false, comment: "Là tiền tệ chính để quy đổi thống kê"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TienTe", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TienTe_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Tiền tệ người dùng cấu hình");

            migrationBuilder.CreateTable(
                name: "TinNhan",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    HoiThoaiId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Hội thoại"),
                    NguoiGuiId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người gửi"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=chữ, 2=ảnh, 3=hệ thống"),
                    NoiDung = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Nội dung"),
                    TraLoiTinNhanId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Trả lời tin nhắn"),
                    GuiLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm gửi trên máy (có thể lúc offline)"),
                    MayChuNhanLuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm server nhận"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TinNhan", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TinNhan_HoiThoai_HoiThoaiId",
                        column: x => x.HoiThoaiId,
                        principalTable: "HoiThoai",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_TinNhan_NguoiDung_NguoiGuiId",
                        column: x => x.NguoiGuiId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Tin nhắn");

            migrationBuilder.CreateTable(
                name: "TyGia",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    MaTienNguon = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ nguồn"),
                    MaTienDich = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ đích"),
                    TyGia = table.Column<decimal>(type: "decimal(28,10)", precision: 28, scale: 10, nullable: false, comment: "1 đơn vị nguồn = Rate đơn vị đích"),
                    NgayApDung = table.Column<DateOnly>(type: "date", nullable: false, comment: "Ngày bắt đầu áp dụng"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TyGia", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TyGia_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Tỷ giá nhập tay theo ngày");

            migrationBuilder.CreateTable(
                name: "ChucNang",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    PhanHeId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Phân hệ"),
                    ChucNangChaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Chức năng cha (menu nhiều cấp)"),
                    Ma = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false, comment: "Mã chức năng duy nhất, vd QUAN_TRI.VAI_TRO"),
                    Ten = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: false, comment: "Tên chức năng"),
                    DuongDanManHinh = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Đường dẫn màn hình trên app, vd /admin/roles"),
                    BieuTuong = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Tên icon"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    HienMenu = table.Column<bool>(type: "bit", nullable: false, comment: "Hiện trên menu"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChucNang", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ChucNang_ChucNang_ChucNangChaId",
                        column: x => x.ChucNangChaId,
                        principalTable: "ChucNang",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ChucNang_PhanHe_PhanHeId",
                        column: x => x.PhanHeId,
                        principalTable: "PhanHe",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Chức năng / quyền (cũng là mục menu nếu IsShow)");

            migrationBuilder.CreateTable(
                name: "NguoiDungVaiTro",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng"),
                    VaiTroId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Vai trò"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NguoiDungVaiTro", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NguoiDungVaiTro_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NguoiDungVaiTro_VaiTro_VaiTroId",
                        column: x => x.VaiTroId,
                        principalTable: "VaiTro",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Vai trò của người dùng");

            migrationBuilder.CreateTable(
                name: "BinhLuan",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BaiVietId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bài viết"),
                    TacGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người bình luận"),
                    BinhLuanChaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Bình luận cha (trả lời 1 cấp)"),
                    NoiDung = table.Column<string>(type: "nvarchar(max)", nullable: false, comment: "Nội dung"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BinhLuan", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BinhLuan_BaiViet_BaiVietId",
                        column: x => x.BaiVietId,
                        principalTable: "BaiViet",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BinhLuan_BinhLuan_BinhLuanChaId",
                        column: x => x.BinhLuanChaId,
                        principalTable: "BinhLuan",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BinhLuan_NguoiDung_TacGiaId",
                        column: x => x.TacGiaId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Bình luận");

            migrationBuilder.CreateTable(
                name: "NguoiXemBaiViet",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BaiVietId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bài viết"),
                    NguoiXemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người được xem"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NguoiXemBaiViet", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NguoiXemBaiViet_BaiViet_BaiVietId",
                        column: x => x.BaiVietId,
                        principalTable: "BaiViet",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Người được xem bài viết (khi quyền xem = chọn người)");

            migrationBuilder.CreateTable(
                name: "TagBaiViet",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BaiVietId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bài viết"),
                    NguoiDuocTagId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người được tag"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TagBaiViet", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TagBaiViet_BaiViet_BaiVietId",
                        column: x => x.BaiVietId,
                        principalTable: "BaiViet",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Bạn bè được tag trong bài viết");

            migrationBuilder.CreateTable(
                name: "BacGiaDien",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BangGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bảng giá"),
                    Bac = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự bậc (1, 2, 3...)"),
                    TuKwh = table.Column<int>(type: "int", nullable: false, comment: "Từ kWh (bao gồm)"),
                    DenKwh = table.Column<int>(type: "int", nullable: true, comment: "Đến kWh (bao gồm), NULL = không giới hạn"),
                    DonGia = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Đơn giá (đồng/kWh)"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_BacGiaDien", x => x.Id);
                    table.ForeignKey(
                        name: "FK_BacGiaDien_BangGiaDien_BangGiaId",
                        column: x => x.BangGiaId,
                        principalTable: "BangGiaDien",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_BacGiaDien_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Một bậc trong bảng giá điện");

            migrationBuilder.CreateTable(
                name: "HoaDonDien",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    BangGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Bảng giá đã dùng"),
                    Ky = table.Column<DateOnly>(type: "date", nullable: false, comment: "Kỳ (ngày đầu tháng)"),
                    ChiSoCu = table.Column<int>(type: "int", nullable: true, comment: "Chỉ số cũ"),
                    ChiSoMoi = table.Column<int>(type: "int", nullable: true, comment: "Chỉ số mới"),
                    SoKwh = table.Column<int>(type: "int", nullable: false, comment: "Số kWh tiêu thụ"),
                    SoTien = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Số tiền (đã gồm VAT, phí)"),
                    ChiTietJson = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Chi tiết từng bậc (JSON)"),
                    GiaoDichId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Giao dịch đã tạo từ hoá đơn này"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HoaDonDien", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HoaDonDien_BangGiaDien_BangGiaId",
                        column: x => x.BangGiaId,
                        principalTable: "BangGiaDien",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_HoaDonDien_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Lịch sử tiền điện từng kỳ");

            migrationBuilder.CreateTable(
                name: "LichSuHu",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    HuTietKiemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Hũ tiết kiệm"),
                    TaiKhoanId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tài khoản lấy tiền / nhận tiền"),
                    SoTien = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Số tiền: dương = nạp, âm = rút"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    ThoiDiem = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm nạp/rút"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LichSuHu", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LichSuHu_HuTietKiem_HuTietKiemId",
                        column: x => x.HuTietKiemId,
                        principalTable: "HuTietKiem",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LichSuHu_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Lịch sử nạp / rút hũ tiết kiệm");

            migrationBuilder.CreateTable(
                name: "LichTrinh",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    TieuDe = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false, comment: "Tiêu đề"),
                    BatDau = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Bắt đầu"),
                    KetThuc = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Kết thúc"),
                    CaNgay = table.Column<bool>(type: "bit", nullable: false, comment: "Cả ngày"),
                    DiaDiem = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Địa điểm"),
                    ViDo = table.Column<double>(type: "float", nullable: true, comment: "Vĩ độ"),
                    KinhDo = table.Column<double>(type: "float", nullable: true, comment: "Kinh độ"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    PhanLoai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=đi chơi, 2=công việc, 99=khác"),
                    MauSac = table.Column<string>(type: "nvarchar(9)", maxLength: 9, nullable: true, comment: "Màu (hex)"),
                    QuyTacLap = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Quy tắc lặp RRULE, NULL = không lặp"),
                    LapDen = table.Column<DateOnly>(type: "date", nullable: true, comment: "Lặp đến ngày"),
                    NhacTruocPhut = table.Column<int>(type: "int", nullable: true, comment: "Nhắc trước bao nhiêu phút, NULL = không nhắc"),
                    KeHoachId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Thuộc kế hoạch chung"),
                    AnhBiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Ảnh bìa (StoredFiles.Id)"),
                    ChiPhiDuKien = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: true, comment: "Chi phí dự kiến"),
                    MaTienTe = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: true, comment: "Mã tiền tệ của chi phí"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_LichTrinh", x => x.Id);
                    table.ForeignKey(
                        name: "FK_LichTrinh_KeHoach_KeHoachId",
                        column: x => x.KeHoachId,
                        principalTable: "KeHoach",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_LichTrinh_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Lịch trình / sự kiện");

            migrationBuilder.CreateTable(
                name: "ThanhVienKeHoach",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    KeHoachId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Kế hoạch"),
                    ThanhVienId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Thành viên"),
                    VaiTro = table.Column<byte>(type: "tinyint", nullable: false, comment: "Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem"),
                    TrangThai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ThanhVienKeHoach", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ThanhVienKeHoach_KeHoach_KeHoachId",
                        column: x => x.KeHoachId,
                        principalTable: "KeHoach",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ThanhVienKeHoach_NguoiDung_ThanhVienId",
                        column: x => x.ThanhVienId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Thành viên kế hoạch chung");

            migrationBuilder.CreateTable(
                name: "GiaoDich",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    Loai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại: 1=chi, 2=thu, 3=chuyển khoản"),
                    SoTien = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: false, comment: "Số tiền (luôn dương) theo tiền tệ của tài khoản nguồn"),
                    MaTienTe = table.Column<string>(type: "nvarchar(10)", maxLength: 10, nullable: false, comment: "Mã tiền tệ của số tiền"),
                    TaiKhoanId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Tài khoản nguồn"),
                    TaiKhoanNhanId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Tài khoản nhận (chỉ khi chuyển khoản)"),
                    SoTienNhan = table.Column<decimal>(type: "decimal(19,4)", precision: 19, scale: 4, nullable: true, comment: "Số tiền tài khoản nhận được (khi khác tiền tệ)"),
                    DanhMucId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Danh mục (NULL khi chuyển khoản)"),
                    ThoiDiem = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm phát sinh"),
                    GhiChu = table.Column<string>(type: "nvarchar(max)", nullable: true, comment: "Ghi chú"),
                    LichTrinhId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Gắn với lịch trình"),
                    HuTietKiemId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Gắn với hũ tiết kiệm"),
                    GiaoDichDinhKyId = table.Column<Guid>(type: "uniqueidentifier", nullable: true, comment: "Sinh ra từ giao dịch định kỳ"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GiaoDich", x => x.Id);
                    table.ForeignKey(
                        name: "FK_GiaoDich_DanhMuc_DanhMucId",
                        column: x => x.DanhMucId,
                        principalTable: "DanhMuc",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GiaoDich_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GiaoDich_TaiKhoan_TaiKhoanId",
                        column: x => x.TaiKhoanId,
                        principalTable: "TaiKhoan",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_GiaoDich_TaiKhoan_TaiKhoanNhanId",
                        column: x => x.TaiKhoanNhanId,
                        principalTable: "TaiKhoan",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Giao dịch thu / chi / chuyển khoản");

            migrationBuilder.CreateTable(
                name: "AnhDinhKem",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    LoaiDoiTuong = table.Column<byte>(type: "tinyint", nullable: false, comment: "Loại đối tượng: 1=giao dịch, 2=lịch trình, 3=bài viết, 4=tin nhắn, 5=hoá đơn điện, 6=hũ"),
                    DoiTuongId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Id đối tượng sở hữu ảnh"),
                    TepTinId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "File (StoredFiles.Id)"),
                    ChuThich = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Chú thích ảnh"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá"),
                    NguoiDungId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người dùng sở hữu bản ghi")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AnhDinhKem", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AnhDinhKem_NguoiDung_NguoiDungId",
                        column: x => x.NguoiDungId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AnhDinhKem_TepTin_TepTinId",
                        column: x => x.TepTinId,
                        principalTable: "TepTin",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Ảnh đính kèm cho giao dịch / lịch trình / bài viết / tin nhắn...");

            migrationBuilder.CreateTable(
                name: "VaiTroChucNang",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    VaiTroId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Vai trò"),
                    ChucNangId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Chức năng"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_VaiTroChucNang", x => x.Id);
                    table.ForeignKey(
                        name: "FK_VaiTroChucNang_ChucNang_ChucNangId",
                        column: x => x.ChucNangId,
                        principalTable: "ChucNang",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_VaiTroChucNang_VaiTro_VaiTroId",
                        column: x => x.VaiTroId,
                        principalTable: "VaiTro",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Chức năng được cấp cho vai trò");

            migrationBuilder.CreateTable(
                name: "AnhLichTrinh",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    LichTrinhId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Lịch trình"),
                    NgayLanLap = table.Column<DateOnly>(type: "date", nullable: true, comment: "Ngày của lần lặp (NULL nếu lịch không lặp)"),
                    TepTinId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "File ảnh (StoredFiles.Id)"),
                    NguoiThemId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người thêm ảnh"),
                    ChuThich = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true, comment: "Chú thích"),
                    ThuTu = table.Column<int>(type: "int", nullable: false, comment: "Thứ tự hiển thị"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AnhLichTrinh", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AnhLichTrinh_LichTrinh_LichTrinhId",
                        column: x => x.LichTrinhId,
                        principalTable: "LichTrinh",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_AnhLichTrinh_TepTin_TepTinId",
                        column: x => x.TepTinId,
                        principalTable: "TepTin",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Ảnh album của lịch trình (theo từng lần lặp)");

            migrationBuilder.CreateTable(
                name: "NguoiThamGiaLichTrinh",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Khoá chính (UUID v7 do app sinh)"),
                    LichTrinhId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Lịch trình"),
                    NguoiThamGiaId = table.Column<Guid>(type: "uniqueidentifier", nullable: false, comment: "Người tham gia"),
                    TrangThai = table.Column<byte>(type: "tinyint", nullable: false, comment: "Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối"),
                    VaiTro = table.Column<byte>(type: "tinyint", nullable: false, comment: "Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem"),
                    NgayTao = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm tạo (UTC)"),
                    NgayCapNhat = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: false, comment: "Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ"),
                    NgayXoa = table.Column<DateTimeOffset>(type: "datetimeoffset", nullable: true, comment: "Thời điểm xoá mềm (UTC), NULL = chưa xoá")
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NguoiThamGiaLichTrinh", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NguoiThamGiaLichTrinh_LichTrinh_LichTrinhId",
                        column: x => x.LichTrinhId,
                        principalTable: "LichTrinh",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NguoiThamGiaLichTrinh_NguoiDung_NguoiThamGiaId",
                        column: x => x.NguoiThamGiaId,
                        principalTable: "NguoiDung",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                },
                comment: "Người tham gia lịch trình chung");

            migrationBuilder.CreateIndex(
                name: "IX_AnhDinhKem_LoaiDoiTuong_DoiTuongId",
                table: "AnhDinhKem",
                columns: new[] { "LoaiDoiTuong", "DoiTuongId" });

            migrationBuilder.CreateIndex(
                name: "IX_AnhDinhKem_NguoiDungId_NgayCapNhat",
                table: "AnhDinhKem",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_AnhDinhKem_TepTinId",
                table: "AnhDinhKem",
                column: "TepTinId");

            migrationBuilder.CreateIndex(
                name: "IX_AnhLichTrinh_LichTrinhId_NgayLanLap",
                table: "AnhLichTrinh",
                columns: new[] { "LichTrinhId", "NgayLanLap" });

            migrationBuilder.CreateIndex(
                name: "IX_AnhLichTrinh_NgayCapNhat",
                table: "AnhLichTrinh",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_AnhLichTrinh_TepTinId",
                table: "AnhLichTrinh",
                column: "TepTinId");

            migrationBuilder.CreateIndex(
                name: "IX_BacGiaDien_BangGiaId_Bac",
                table: "BacGiaDien",
                columns: new[] { "BangGiaId", "Bac" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_BacGiaDien_NguoiDungId_NgayCapNhat",
                table: "BacGiaDien",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_BaiViet_NgayCapNhat",
                table: "BaiViet",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_BaiViet_TacGiaId_NgayTao",
                table: "BaiViet",
                columns: new[] { "TacGiaId", "NgayTao" });

            migrationBuilder.CreateIndex(
                name: "IX_BanBe_NgayCapNhat",
                table: "BanBe",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_BanBe_NguoiDuocMoiId_TrangThai",
                table: "BanBe",
                columns: new[] { "NguoiDuocMoiId", "TrangThai" });

            migrationBuilder.CreateIndex(
                name: "IX_BanBe_NguoiMoiId_NguoiDuocMoiId",
                table: "BanBe",
                columns: new[] { "NguoiMoiId", "NguoiDuocMoiId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_BangGiaDien_NguoiDungId_NgayCapNhat",
                table: "BangGiaDien",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_BinhLuan_BaiVietId_NgayTao",
                table: "BinhLuan",
                columns: new[] { "BaiVietId", "NgayTao" });

            migrationBuilder.CreateIndex(
                name: "IX_BinhLuan_BinhLuanChaId",
                table: "BinhLuan",
                column: "BinhLuanChaId");

            migrationBuilder.CreateIndex(
                name: "IX_BinhLuan_NgayCapNhat",
                table: "BinhLuan",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_BinhLuan_TacGiaId",
                table: "BinhLuan",
                column: "TacGiaId");

            migrationBuilder.CreateIndex(
                name: "IX_CaiDat_NguoiDungId",
                table: "CaiDat",
                column: "NguoiDungId",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CaiDat_NguoiDungId_NgayCapNhat",
                table: "CaiDat",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_CamXuc_LoaiDoiTuong_DoiTuongId_NguoiTuongTacId",
                table: "CamXuc",
                columns: new[] { "LoaiDoiTuong", "DoiTuongId", "NguoiTuongTacId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CamXuc_NgayCapNhat",
                table: "CamXuc",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_CamXuc_NguoiTuongTacId",
                table: "CamXuc",
                column: "NguoiTuongTacId");

            migrationBuilder.CreateIndex(
                name: "IX_CauHinhChuKy_NguoiDungId_DoiTuong",
                table: "CauHinhChuKy",
                columns: new[] { "NguoiDungId", "DoiTuong" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_CauHinhChuKy_NguoiDungId_NgayCapNhat",
                table: "CauHinhChuKy",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_ChucNang_ChucNangChaId",
                table: "ChucNang",
                column: "ChucNangChaId");

            migrationBuilder.CreateIndex(
                name: "IX_ChucNang_Ma",
                table: "ChucNang",
                column: "Ma",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ChucNang_NgayCapNhat",
                table: "ChucNang",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_ChucNang_PhanHeId",
                table: "ChucNang",
                column: "PhanHeId");

            migrationBuilder.CreateIndex(
                name: "IX_DanhMuc_DanhMucChaId",
                table: "DanhMuc",
                column: "DanhMucChaId");

            migrationBuilder.CreateIndex(
                name: "IX_DanhMuc_NguoiDungId_Loai_DanhMucChaId",
                table: "DanhMuc",
                columns: new[] { "NguoiDungId", "Loai", "DanhMucChaId" });

            migrationBuilder.CreateIndex(
                name: "IX_DanhMuc_NguoiDungId_NgayCapNhat",
                table: "DanhMuc",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_DemNgayYeu_NguoiDungId",
                table: "DemNgayYeu",
                column: "NguoiDungId",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_DemNgayYeu_NguoiDungId_NgayCapNhat",
                table: "DemNgayYeu",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_DinhMuc_NguoiDungId_NgayCapNhat",
                table: "DinhMuc",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_DanhMucId",
                table: "GiaoDich",
                column: "DanhMucId");

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_LichTrinhId",
                table: "GiaoDich",
                column: "LichTrinhId");

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_NguoiDungId_DanhMucId_ThoiDiem",
                table: "GiaoDich",
                columns: new[] { "NguoiDungId", "DanhMucId", "ThoiDiem" });

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_NguoiDungId_NgayCapNhat",
                table: "GiaoDich",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_NguoiDungId_TaiKhoanId_ThoiDiem",
                table: "GiaoDich",
                columns: new[] { "NguoiDungId", "TaiKhoanId", "ThoiDiem" });

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_NguoiDungId_ThoiDiem",
                table: "GiaoDich",
                columns: new[] { "NguoiDungId", "ThoiDiem" });

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_TaiKhoanId",
                table: "GiaoDich",
                column: "TaiKhoanId");

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDich_TaiKhoanNhanId",
                table: "GiaoDich",
                column: "TaiKhoanNhanId");

            migrationBuilder.CreateIndex(
                name: "IX_GiaoDichDinhKy_NguoiDungId_NgayCapNhat",
                table: "GiaoDichDinhKy",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_HoaDonDien_BangGiaId",
                table: "HoaDonDien",
                column: "BangGiaId");

            migrationBuilder.CreateIndex(
                name: "IX_HoaDonDien_NguoiDungId_Ky",
                table: "HoaDonDien",
                columns: new[] { "NguoiDungId", "Ky" });

            migrationBuilder.CreateIndex(
                name: "IX_HoaDonDien_NguoiDungId_NgayCapNhat",
                table: "HoaDonDien",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_HoiThoai_NgayCapNhat",
                table: "HoiThoai",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_HoiThoai_TinNhanCuoiLuc",
                table: "HoiThoai",
                column: "TinNhanCuoiLuc");

            migrationBuilder.CreateIndex(
                name: "IX_HuTietKiem_NguoiDungId_NgayCapNhat",
                table: "HuTietKiem",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_KeHoach_NguoiDungId_NgayCapNhat",
                table: "KeHoach",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_KyKinh_NguoiDungId_DoiTuong_NgayBatDau",
                table: "KyKinh",
                columns: new[] { "NguoiDungId", "DoiTuong", "NgayBatDau" });

            migrationBuilder.CreateIndex(
                name: "IX_KyKinh_NguoiDungId_NgayCapNhat",
                table: "KyKinh",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_LichSuHu_HuTietKiemId_ThoiDiem",
                table: "LichSuHu",
                columns: new[] { "HuTietKiemId", "ThoiDiem" });

            migrationBuilder.CreateIndex(
                name: "IX_LichSuHu_NguoiDungId_NgayCapNhat",
                table: "LichSuHu",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinh_KeHoachId",
                table: "LichTrinh",
                column: "KeHoachId");

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinh_NguoiDungId_BatDau",
                table: "LichTrinh",
                columns: new[] { "NguoiDungId", "BatDau" });

            migrationBuilder.CreateIndex(
                name: "IX_LichTrinh_NguoiDungId_NgayCapNhat",
                table: "LichTrinh",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_MaLamMoi_MaBam",
                table: "MaLamMoi",
                column: "MaBam",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_MaLamMoi_NguoiDungId_NgayCapNhat",
                table: "MaLamMoi",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDung_Email",
                table: "NguoiDung",
                column: "Email",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDung_NgayCapNhat",
                table: "NguoiDung",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDung_TenDangNhap",
                table: "NguoiDung",
                column: "TenDangNhap",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDungVaiTro_NgayCapNhat",
                table: "NguoiDungVaiTro",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDungVaiTro_NguoiDungId_VaiTroId",
                table: "NguoiDungVaiTro",
                columns: new[] { "NguoiDungId", "VaiTroId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiDungVaiTro_VaiTroId",
                table: "NguoiDungVaiTro",
                column: "VaiTroId");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiThamGiaLichTrinh_LichTrinhId_NguoiThamGiaId",
                table: "NguoiThamGiaLichTrinh",
                columns: new[] { "LichTrinhId", "NguoiThamGiaId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiThamGiaLichTrinh_NgayCapNhat",
                table: "NguoiThamGiaLichTrinh",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiThamGiaLichTrinh_NguoiThamGiaId",
                table: "NguoiThamGiaLichTrinh",
                column: "NguoiThamGiaId");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiXemBaiViet_BaiVietId_NguoiXemId",
                table: "NguoiXemBaiViet",
                columns: new[] { "BaiVietId", "NguoiXemId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiXemBaiViet_NgayCapNhat",
                table: "NguoiXemBaiViet",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_NguoiXemBaiViet_NguoiXemId",
                table: "NguoiXemBaiViet",
                column: "NguoiXemId");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyChuKy_NguoiDungId_DoiTuong_Ngay",
                table: "NhatKyChuKy",
                columns: new[] { "NguoiDungId", "DoiTuong", "Ngay" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_NhatKyChuKy_NguoiDungId_NgayCapNhat",
                table: "NhatKyChuKy",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_PhanHe_Ma",
                table: "PhanHe",
                column: "Ma",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_PhanHe_NgayCapNhat",
                table: "PhanHe",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_TagBaiViet_BaiVietId_NguoiDuocTagId",
                table: "TagBaiViet",
                columns: new[] { "BaiVietId", "NguoiDuocTagId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_TagBaiViet_NgayCapNhat",
                table: "TagBaiViet",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_TaiKhoan_NguoiDungId_NgayCapNhat",
                table: "TaiKhoan",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_TepTin_NguoiDungId_NgayCapNhat",
                table: "TepTin",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienHoiThoai_HoiThoaiId_ThanhVienId",
                table: "ThanhVienHoiThoai",
                columns: new[] { "HoiThoaiId", "ThanhVienId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienHoiThoai_NgayCapNhat",
                table: "ThanhVienHoiThoai",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienHoiThoai_ThanhVienId",
                table: "ThanhVienHoiThoai",
                column: "ThanhVienId");

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienKeHoach_KeHoachId_ThanhVienId",
                table: "ThanhVienKeHoach",
                columns: new[] { "KeHoachId", "ThanhVienId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienKeHoach_NgayCapNhat",
                table: "ThanhVienKeHoach",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_ThanhVienKeHoach_ThanhVienId",
                table: "ThanhVienKeHoach",
                column: "ThanhVienId");

            migrationBuilder.CreateIndex(
                name: "IX_ThietBi_NguoiDungId_NgayCapNhat",
                table: "ThietBi",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_ThongBao_NguoiDungId_DaDocLuc",
                table: "ThongBao",
                columns: new[] { "NguoiDungId", "DaDocLuc" });

            migrationBuilder.CreateIndex(
                name: "IX_ThongBao_NguoiDungId_NgayCapNhat",
                table: "ThongBao",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_TienTe_NguoiDungId_Ma",
                table: "TienTe",
                columns: new[] { "NguoiDungId", "Ma" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_TienTe_NguoiDungId_NgayCapNhat",
                table: "TienTe",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_TinNhan_HoiThoaiId_MayChuNhanLuc",
                table: "TinNhan",
                columns: new[] { "HoiThoaiId", "MayChuNhanLuc" });

            migrationBuilder.CreateIndex(
                name: "IX_TinNhan_NgayCapNhat",
                table: "TinNhan",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_TinNhan_NguoiGuiId",
                table: "TinNhan",
                column: "NguoiGuiId");

            migrationBuilder.CreateIndex(
                name: "IX_TyGia_NguoiDungId_MaTienNguon_MaTienDich_NgayApDung",
                table: "TyGia",
                columns: new[] { "NguoiDungId", "MaTienNguon", "MaTienDich", "NgayApDung" },
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_TyGia_NguoiDungId_NgayCapNhat",
                table: "TyGia",
                columns: new[] { "NguoiDungId", "NgayCapNhat" });

            migrationBuilder.CreateIndex(
                name: "IX_VaiTro_Ma",
                table: "VaiTro",
                column: "Ma",
                unique: true,
                filter: "[NgayXoa] IS NULL");

            migrationBuilder.CreateIndex(
                name: "IX_VaiTro_NgayCapNhat",
                table: "VaiTro",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_VaiTroChucNang_ChucNangId",
                table: "VaiTroChucNang",
                column: "ChucNangId");

            migrationBuilder.CreateIndex(
                name: "IX_VaiTroChucNang_NgayCapNhat",
                table: "VaiTroChucNang",
                column: "NgayCapNhat");

            migrationBuilder.CreateIndex(
                name: "IX_VaiTroChucNang_VaiTroId_ChucNangId",
                table: "VaiTroChucNang",
                columns: new[] { "VaiTroId", "ChucNangId" },
                unique: true,
                filter: "[NgayXoa] IS NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AnhDinhKem");

            migrationBuilder.DropTable(
                name: "AnhLichTrinh");

            migrationBuilder.DropTable(
                name: "BacGiaDien");

            migrationBuilder.DropTable(
                name: "BanBe");

            migrationBuilder.DropTable(
                name: "BinhLuan");

            migrationBuilder.DropTable(
                name: "CaiDat");

            migrationBuilder.DropTable(
                name: "CamXuc");

            migrationBuilder.DropTable(
                name: "CauHinhChuKy");

            migrationBuilder.DropTable(
                name: "DemNgayYeu");

            migrationBuilder.DropTable(
                name: "DinhMuc");

            migrationBuilder.DropTable(
                name: "GiaoDich");

            migrationBuilder.DropTable(
                name: "GiaoDichDinhKy");

            migrationBuilder.DropTable(
                name: "HoaDonDien");

            migrationBuilder.DropTable(
                name: "KyKinh");

            migrationBuilder.DropTable(
                name: "LichSuHu");

            migrationBuilder.DropTable(
                name: "MaLamMoi");

            migrationBuilder.DropTable(
                name: "NguoiDungVaiTro");

            migrationBuilder.DropTable(
                name: "NguoiThamGiaLichTrinh");

            migrationBuilder.DropTable(
                name: "NguoiXemBaiViet");

            migrationBuilder.DropTable(
                name: "NhatKyChuKy");

            migrationBuilder.DropTable(
                name: "TagBaiViet");

            migrationBuilder.DropTable(
                name: "ThanhVienHoiThoai");

            migrationBuilder.DropTable(
                name: "ThanhVienKeHoach");

            migrationBuilder.DropTable(
                name: "ThietBi");

            migrationBuilder.DropTable(
                name: "ThongBao");

            migrationBuilder.DropTable(
                name: "TienTe");

            migrationBuilder.DropTable(
                name: "TinNhan");

            migrationBuilder.DropTable(
                name: "TyGia");

            migrationBuilder.DropTable(
                name: "VaiTroChucNang");

            migrationBuilder.DropTable(
                name: "TepTin");

            migrationBuilder.DropTable(
                name: "DanhMuc");

            migrationBuilder.DropTable(
                name: "TaiKhoan");

            migrationBuilder.DropTable(
                name: "BangGiaDien");

            migrationBuilder.DropTable(
                name: "HuTietKiem");

            migrationBuilder.DropTable(
                name: "LichTrinh");

            migrationBuilder.DropTable(
                name: "BaiViet");

            migrationBuilder.DropTable(
                name: "HoiThoai");

            migrationBuilder.DropTable(
                name: "ChucNang");

            migrationBuilder.DropTable(
                name: "VaiTro");

            migrationBuilder.DropTable(
                name: "KeHoach");

            migrationBuilder.DropTable(
                name: "PhanHe");

            migrationBuilder.DropTable(
                name: "NguoiDung");
        }
    }
}
