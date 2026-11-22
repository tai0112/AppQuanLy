IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [HoiThoai] (
        [Id] uniqueidentifier NOT NULL,
        [Loai] tinyint NOT NULL,
        [Ten] nvarchar(100) NULL,
        [AnhDaiDienId] uniqueidentifier NULL,
        [NguoiTaoId] uniqueidentifier NOT NULL,
        [TinNhanCuoiId] uniqueidentifier NULL,
        [TinNhanCuoiLuc] datetimeoffset NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_HoiThoai] PRIMARY KEY ([Id])
    );
    DECLARE @defaultSchema AS sysname;
    SET @defaultSchema = SCHEMA_NAME();
    DECLARE @description AS sql_variant;
    SET @description = N'Hội thoại chat';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai';
    SET @description = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'Id';
    SET @description = N'Loại: 1=1-1, 2=nhóm';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'Loai';
    SET @description = N'Tên nhóm';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'Ten';
    SET @description = N'Ảnh nhóm (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'AnhDaiDienId';
    SET @description = N'Người tạo';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'NguoiTaoId';
    SET @description = N'Tin nhắn cuối (để sắp xếp danh sách)';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'TinNhanCuoiId';
    SET @description = N'Thời điểm tin nhắn cuối';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'TinNhanCuoiLuc';
    SET @description = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'NgayTao';
    SET @description = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'NgayCapNhat';
    SET @description = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description, 'SCHEMA', @defaultSchema, 'TABLE', N'HoiThoai', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [NguoiDung] (
        [Id] uniqueidentifier NOT NULL,
        [Email] nvarchar(256) NOT NULL,
        [TenDangNhap] nvarchar(50) NOT NULL,
        [MatKhauBam] nvarchar(500) NOT NULL,
        [TenHienThi] nvarchar(100) NOT NULL,
        [AnhDaiDienId] uniqueidentifier NULL,
        [GioiThieu] nvarchar(max) NULL,
        [NgaySinh] date NULL,
        [HoatDongLanCuoi] datetimeoffset NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_NguoiDung] PRIMARY KEY ([Id])
    );
    DECLARE @defaultSchema1 AS sysname;
    SET @defaultSchema1 = SCHEMA_NAME();
    DECLARE @description1 AS sql_variant;
    SET @description1 = N'Người dùng';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung';
    SET @description1 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'Id';
    SET @description1 = N'Email đăng nhập (duy nhất)';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'Email';
    SET @description1 = N'Tên người dùng để tìm kiếm, kết bạn (duy nhất)';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'TenDangNhap';
    SET @description1 = N'Mật khẩu đã băm';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'MatKhauBam';
    SET @description1 = N'Tên hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'TenHienThi';
    SET @description1 = N'Ảnh đại diện (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'AnhDaiDienId';
    SET @description1 = N'Giới thiệu ngắn';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'GioiThieu';
    SET @description1 = N'Ngày sinh';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'NgaySinh';
    SET @description1 = N'Lần hoạt động gần nhất';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'HoatDongLanCuoi';
    SET @description1 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'NgayTao';
    SET @description1 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'NgayCapNhat';
    SET @description1 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description1, 'SCHEMA', @defaultSchema1, 'TABLE', N'NguoiDung', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [PhanHe] (
        [Id] uniqueidentifier NOT NULL,
        [Ma] nvarchar(100) NOT NULL,
        [Ten] nvarchar(500) NOT NULL,
        [BieuTuong] nvarchar(500) NULL,
        [ThuTu] int NOT NULL,
        [HienMenu] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_PhanHe] PRIMARY KEY ([Id])
    );
    DECLARE @defaultSchema2 AS sysname;
    SET @defaultSchema2 = SCHEMA_NAME();
    DECLARE @description2 AS sql_variant;
    SET @description2 = N'Phân hệ (nhóm chức năng)';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe';
    SET @description2 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'Id';
    SET @description2 = N'Mã phân hệ, vd QUAN_TRI';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'Ma';
    SET @description2 = N'Tên phân hệ';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'Ten';
    SET @description2 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'BieuTuong';
    SET @description2 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'ThuTu';
    SET @description2 = N'Hiện trên menu';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'HienMenu';
    SET @description2 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'NgayTao';
    SET @description2 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'NgayCapNhat';
    SET @description2 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description2, 'SCHEMA', @defaultSchema2, 'TABLE', N'PhanHe', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [VaiTro] (
        [Id] uniqueidentifier NOT NULL,
        [Ma] nvarchar(50) NOT NULL,
        [Ten] nvarchar(500) NOT NULL,
        [MoTa] nvarchar(max) NULL,
        [DangBat] bit NOT NULL,
        [LaHeThong] bit NOT NULL,
        [MacDinh] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_VaiTro] PRIMARY KEY ([Id])
    );
    DECLARE @defaultSchema3 AS sysname;
    SET @defaultSchema3 = SCHEMA_NAME();
    DECLARE @description3 AS sql_variant;
    SET @description3 = N'Vai trò';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro';
    SET @description3 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'Id';
    SET @description3 = N'Mã vai trò, vd ADMIN, USER';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'Ma';
    SET @description3 = N'Tên vai trò';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'Ten';
    SET @description3 = N'Mô tả';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'MoTa';
    SET @description3 = N'Đang bật';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'DangBat';
    SET @description3 = N'Vai trò hệ thống (không cho xoá)';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'LaHeThong';
    SET @description3 = N'Tự gán cho người dùng mới đăng ký';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'MacDinh';
    SET @description3 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'NgayTao';
    SET @description3 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'NgayCapNhat';
    SET @description3 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description3, 'SCHEMA', @defaultSchema3, 'TABLE', N'VaiTro', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [BaiViet] (
        [Id] uniqueidentifier NOT NULL,
        [TacGiaId] uniqueidentifier NOT NULL,
        [NoiDung] nvarchar(max) NULL,
        [QuyenXem] tinyint NOT NULL,
        [LichTrinhId] uniqueidentifier NULL,
        [HuTietKiemId] uniqueidentifier NULL,
        [DiaDiem] nvarchar(500) NULL,
        [CamXuc] nvarchar(100) NULL,
        [SoCamXuc] int NOT NULL,
        [SoBinhLuan] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_BaiViet] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BaiViet_NguoiDung_TacGiaId] FOREIGN KEY ([TacGiaId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema4 AS sysname;
    SET @defaultSchema4 = SCHEMA_NAME();
    DECLARE @description4 AS sql_variant;
    SET @description4 = N'Bài viết';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet';
    SET @description4 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'Id';
    SET @description4 = N'Tác giả';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'TacGiaId';
    SET @description4 = N'Nội dung';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'NoiDung';
    SET @description4 = N'Quyền xem: 1=bạn bè, 2=chỉ mình tôi, 3=chọn người';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'QuyenXem';
    SET @description4 = N'Gắn lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'LichTrinhId';
    SET @description4 = N'Gắn hũ tiết kiệm';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'HuTietKiemId';
    SET @description4 = N'Địa điểm';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'DiaDiem';
    SET @description4 = N'Cảm xúc / trạng thái';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'CamXuc';
    SET @description4 = N'Số cảm xúc (đếm sẵn)';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'SoCamXuc';
    SET @description4 = N'Số bình luận (đếm sẵn)';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'SoBinhLuan';
    SET @description4 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'NgayTao';
    SET @description4 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'NgayCapNhat';
    SET @description4 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description4, 'SCHEMA', @defaultSchema4, 'TABLE', N'BaiViet', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [BanBe] (
        [Id] uniqueidentifier NOT NULL,
        [NguoiMoiId] uniqueidentifier NOT NULL,
        [NguoiDuocMoiId] uniqueidentifier NOT NULL,
        [TrangThai] tinyint NOT NULL,
        [ChapNhanLuc] datetimeoffset NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_BanBe] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BanBe_NguoiDung_NguoiDuocMoiId] FOREIGN KEY ([NguoiDuocMoiId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_BanBe_NguoiDung_NguoiMoiId] FOREIGN KEY ([NguoiMoiId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema5 AS sysname;
    SET @defaultSchema5 = SCHEMA_NAME();
    DECLARE @description5 AS sql_variant;
    SET @description5 = N'Quan hệ bạn bè / lời mời kết bạn';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe';
    SET @description5 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'Id';
    SET @description5 = N'Người gửi lời mời';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'NguoiMoiId';
    SET @description5 = N'Người nhận lời mời';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'NguoiDuocMoiId';
    SET @description5 = N'Trạng thái: 1=chờ, 2=bạn bè, 3=chặn';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'TrangThai';
    SET @description5 = N'Thời điểm chấp nhận';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'ChapNhanLuc';
    SET @description5 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'NgayTao';
    SET @description5 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'NgayCapNhat';
    SET @description5 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description5, 'SCHEMA', @defaultSchema5, 'TABLE', N'BanBe', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [BangGiaDien] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [ThueVat] decimal(5,2) NOT NULL,
        [PhiCoDinh] decimal(19,4) NOT NULL,
        [MacDinh] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_BangGiaDien] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BangGiaDien_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema6 AS sysname;
    SET @defaultSchema6 = SCHEMA_NAME();
    DECLARE @description6 AS sql_variant;
    SET @description6 = N'Bảng giá điện bậc thang';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien';
    SET @description6 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'Id';
    SET @description6 = N'Tên bảng giá, vd EVN sinh hoạt 2025';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'Ten';
    SET @description6 = N'Thuế VAT (%)';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'ThueVat';
    SET @description6 = N'Phí cố định mỗi kỳ';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'PhiCoDinh';
    SET @description6 = N'Bảng giá mặc định';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'MacDinh';
    SET @description6 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'NgayTao';
    SET @description6 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'NgayCapNhat';
    SET @description6 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'NgayXoa';
    SET @description6 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description6, 'SCHEMA', @defaultSchema6, 'TABLE', N'BangGiaDien', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [CaiDat] (
        [Id] uniqueidentifier NOT NULL,
        [BoCucMenuJson] nvarchar(max) NULL,
        [GiaoDien] nvarchar(20) NOT NULL,
        [MauChuDao] nvarchar(9) NULL,
        [MaTienChinh] nvarchar(10) NOT NULL,
        [NgayBatDauThang] tinyint NOT NULL,
        [NgayDauTuan] tinyint NOT NULL,
        [ThongBaoJson] nvarchar(max) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_CaiDat] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CaiDat_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema7 AS sysname;
    SET @defaultSchema7 = SCHEMA_NAME();
    DECLARE @description7 AS sql_variant;
    SET @description7 = N'Cài đặt app của người dùng';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat';
    SET @description7 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'Id';
    SET @description7 = N'Bố cục menu, tiện ích trang chủ (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'BoCucMenuJson';
    SET @description7 = N'Giao diện: system/light/dark';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'GiaoDien';
    SET @description7 = N'Màu chủ đạo (hex)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'MauChuDao';
    SET @description7 = N'Mã tiền tệ chính';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'MaTienChinh';
    SET @description7 = N'Ngày bắt đầu tháng tài chính (1-28)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NgayBatDauThang';
    SET @description7 = N'Ngày đầu tuần: 1=Thứ hai, 7=Chủ nhật';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NgayDauTuan';
    SET @description7 = N'Cấu hình thông báo (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'ThongBaoJson';
    SET @description7 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NgayTao';
    SET @description7 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NgayCapNhat';
    SET @description7 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NgayXoa';
    SET @description7 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description7, 'SCHEMA', @defaultSchema7, 'TABLE', N'CaiDat', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [CamXuc] (
        [Id] uniqueidentifier NOT NULL,
        [LoaiDoiTuong] tinyint NOT NULL,
        [DoiTuongId] uniqueidentifier NOT NULL,
        [NguoiTuongTacId] uniqueidentifier NOT NULL,
        [PhanLoai] tinyint NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_CamXuc] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CamXuc_NguoiDung_NguoiTuongTacId] FOREIGN KEY ([NguoiTuongTacId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema8 AS sysname;
    SET @defaultSchema8 = SCHEMA_NAME();
    DECLARE @description8 AS sql_variant;
    SET @description8 = N'Cảm xúc (like, tim...)';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc';
    SET @description8 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'Id';
    SET @description8 = N'Đối tượng: 1=bài viết, 2=bình luận';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'LoaiDoiTuong';
    SET @description8 = N'Id bài viết / bình luận';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'DoiTuongId';
    SET @description8 = N'Người thả cảm xúc';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'NguoiTuongTacId';
    SET @description8 = N'Loại: 1=like, 2=tim, 3=haha, 4=wow, 5=buồn, 6=giận';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'PhanLoai';
    SET @description8 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'NgayTao';
    SET @description8 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'NgayCapNhat';
    SET @description8 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description8, 'SCHEMA', @defaultSchema8, 'TABLE', N'CamXuc', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [CauHinhChuKy] (
        [Id] uniqueidentifier NOT NULL,
        [DoiTuong] tinyint NOT NULL,
        [SoNgayChuKy] int NOT NULL,
        [SoNgayHanhKinh] int NOT NULL,
        [SoNgayHoangThe] int NOT NULL,
        [SoNgayThuThaiTruoc] int NOT NULL,
        [SoNgayThuThaiSau] int NOT NULL,
        [NhacNhoJson] nvarchar(max) NULL,
        [ChoPhepDongBo] bit NOT NULL,
        [ChiaSeNguoiAy] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_CauHinhChuKy] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CauHinhChuKy_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema9 AS sysname;
    SET @defaultSchema9 = SCHEMA_NAME();
    DECLARE @description9 AS sql_variant;
    SET @description9 = N'Cấu hình theo dõi chu kỳ';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy';
    SET @description9 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'Id';
    SET @description9 = N'Theo dõi cho: 1=bản thân, 2=người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'DoiTuong';
    SET @description9 = N'Độ dài chu kỳ mặc định (ngày)';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'SoNgayChuKy';
    SET @description9 = N'Số ngày hành kinh mặc định';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'SoNgayHanhKinh';
    SET @description9 = N'Pha hoàng thể (ngày từ rụng trứng tới kỳ sau)';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'SoNgayHoangThe';
    SET @description9 = N'Số ngày dễ thụ thai trước rụng trứng';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'SoNgayThuThaiTruoc';
    SET @description9 = N'Số ngày dễ thụ thai sau rụng trứng';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'SoNgayThuThaiSau';
    SET @description9 = N'Cấu hình nhắc nhở (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'NhacNhoJson';
    SET @description9 = N'Cho phép đồng bộ dữ liệu chu kỳ lên server';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'ChoPhepDongBo';
    SET @description9 = N'Chia sẻ cho người yêu xem';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'ChiaSeNguoiAy';
    SET @description9 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'NgayTao';
    SET @description9 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'NgayCapNhat';
    SET @description9 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'NgayXoa';
    SET @description9 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description9, 'SCHEMA', @defaultSchema9, 'TABLE', N'CauHinhChuKy', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [DanhMuc] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [Loai] tinyint NOT NULL,
        [DanhMucChaId] uniqueidentifier NULL,
        [BieuTuong] nvarchar(50) NULL,
        [MauSac] nvarchar(9) NULL,
        [ThuTu] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_DanhMuc] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DanhMuc_DanhMuc_DanhMucChaId] FOREIGN KEY ([DanhMucChaId]) REFERENCES [DanhMuc] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_DanhMuc_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema10 AS sysname;
    SET @defaultSchema10 = SCHEMA_NAME();
    DECLARE @description10 AS sql_variant;
    SET @description10 = N'Danh mục thu/chi (2 cấp)';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc';
    SET @description10 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'Id';
    SET @description10 = N'Tên danh mục';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'Ten';
    SET @description10 = N'Loại: 1=chi, 2=thu';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'Loai';
    SET @description10 = N'Danh mục cha, NULL = danh mục cấp 1';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'DanhMucChaId';
    SET @description10 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'BieuTuong';
    SET @description10 = N'Màu (hex)';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'MauSac';
    SET @description10 = N'Thứ tự sắp xếp';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'ThuTu';
    SET @description10 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'NgayTao';
    SET @description10 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'NgayCapNhat';
    SET @description10 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'NgayXoa';
    SET @description10 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description10, 'SCHEMA', @defaultSchema10, 'TABLE', N'DanhMuc', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [DemNgayYeu] (
        [Id] uniqueidentifier NOT NULL,
        [NgayBatDau] date NOT NULL,
        [TenNguoiAy] nvarchar(100) NOT NULL,
        [SinhNhatNguoiAy] date NULL,
        [NguoiAyId] uniqueidentifier NULL,
        [AnhCuaToiId] uniqueidentifier NULL,
        [AnhNguoiAyId] uniqueidentifier NULL,
        [NhacTruocSoNgay] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_DemNgayYeu] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DemNgayYeu_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema11 AS sysname;
    SET @defaultSchema11 = SCHEMA_NAME();
    DECLARE @description11 AS sql_variant;
    SET @description11 = N'Đếm ngày yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu';
    SET @description11 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'Id';
    SET @description11 = N'Ngày bắt đầu yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NgayBatDau';
    SET @description11 = N'Tên người ấy';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'TenNguoiAy';
    SET @description11 = N'Sinh nhật người ấy';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'SinhNhatNguoiAy';
    SET @description11 = N'Tài khoản người ấy trong app (nếu có)';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NguoiAyId';
    SET @description11 = N'Ảnh của tôi (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'AnhCuaToiId';
    SET @description11 = N'Ảnh người ấy (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'AnhNguoiAyId';
    SET @description11 = N'Nhắc trước mốc bao nhiêu ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NhacTruocSoNgay';
    SET @description11 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NgayTao';
    SET @description11 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NgayCapNhat';
    SET @description11 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NgayXoa';
    SET @description11 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description11, 'SCHEMA', @defaultSchema11, 'TABLE', N'DemNgayYeu', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [DinhMuc] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [PhamVi] tinyint NOT NULL,
        [DoiTuongApDungId] uniqueidentifier NULL,
        [Ky] tinyint NOT NULL,
        [HanMuc] decimal(19,4) NOT NULL,
        [MaTienTe] nvarchar(10) NOT NULL,
        [NguongCanhBao] tinyint NOT NULL,
        [DangBat] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_DinhMuc] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DinhMuc_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema12 AS sysname;
    SET @defaultSchema12 = SCHEMA_NAME();
    DECLARE @description12 AS sql_variant;
    SET @description12 = N'Định mức chi tiêu';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc';
    SET @description12 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'Id';
    SET @description12 = N'Tên định mức';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'Ten';
    SET @description12 = N'Phạm vi: 1=tổng, 2=danh mục, 3=tài khoản';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'PhamVi';
    SET @description12 = N'Id danh mục/tài khoản tương ứng phạm vi';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'DoiTuongApDungId';
    SET @description12 = N'Chu kỳ: 1=ngày, 2=tuần, 3=tháng, 4=năm';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'Ky';
    SET @description12 = N'Hạn mức';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'HanMuc';
    SET @description12 = N'Mã tiền tệ của hạn mức';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'MaTienTe';
    SET @description12 = N'Ngưỡng cảnh báo sắp vượt (%), mặc định 80';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'NguongCanhBao';
    SET @description12 = N'Đang bật';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'DangBat';
    SET @description12 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'NgayTao';
    SET @description12 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'NgayCapNhat';
    SET @description12 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'NgayXoa';
    SET @description12 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description12, 'SCHEMA', @defaultSchema12, 'TABLE', N'DinhMuc', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [GiaoDichDinhKy] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(500) NOT NULL,
        [MauJson] nvarchar(max) NOT NULL,
        [QuyTacLap] nvarchar(max) NOT NULL,
        [LanChayTiepTheo] datetimeoffset NOT NULL,
        [DangBat] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_GiaoDichDinhKy] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_GiaoDichDinhKy_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema13 AS sysname;
    SET @defaultSchema13 = SCHEMA_NAME();
    DECLARE @description13 AS sql_variant;
    SET @description13 = N'Giao dịch định kỳ (tiền nhà, lương...)';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy';
    SET @description13 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'Id';
    SET @description13 = N'Tên quy tắc';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'Ten';
    SET @description13 = N'Mẫu giao dịch (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'MauJson';
    SET @description13 = N'Quy tắc lặp theo chuẩn RRULE (RFC 5545)';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'QuyTacLap';
    SET @description13 = N'Lần chạy kế tiếp';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'LanChayTiepTheo';
    SET @description13 = N'Đang bật';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'DangBat';
    SET @description13 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'NgayTao';
    SET @description13 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'NgayCapNhat';
    SET @description13 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'NgayXoa';
    SET @description13 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description13, 'SCHEMA', @defaultSchema13, 'TABLE', N'GiaoDichDinhKy', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [HuTietKiem] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [BieuTuong] nvarchar(50) NULL,
        [MauSac] nvarchar(9) NULL,
        [SoTienMucTieu] decimal(19,4) NOT NULL,
        [MaTienTe] nvarchar(10) NOT NULL,
        [HanHoanThanh] date NULL,
        [AnhBiaId] uniqueidentifier NULL,
        [DaDong] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_HuTietKiem] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_HuTietKiem_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema14 AS sysname;
    SET @defaultSchema14 = SCHEMA_NAME();
    DECLARE @description14 AS sql_variant;
    SET @description14 = N'Hũ tiết kiệm';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem';
    SET @description14 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'Id';
    SET @description14 = N'Tên hũ';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'Ten';
    SET @description14 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'BieuTuong';
    SET @description14 = N'Màu (hex)';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'MauSac';
    SET @description14 = N'Số tiền mục tiêu';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'SoTienMucTieu';
    SET @description14 = N'Mã tiền tệ';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'MaTienTe';
    SET @description14 = N'Hạn hoàn thành';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'HanHoanThanh';
    SET @description14 = N'Ảnh bìa (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'AnhBiaId';
    SET @description14 = N'Đã hoàn thành / đóng hũ';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'DaDong';
    SET @description14 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'NgayTao';
    SET @description14 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'NgayCapNhat';
    SET @description14 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'NgayXoa';
    SET @description14 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description14, 'SCHEMA', @defaultSchema14, 'TABLE', N'HuTietKiem', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [KeHoach] (
        [Id] uniqueidentifier NOT NULL,
        [TieuDe] nvarchar(200) NOT NULL,
        [MoTa] nvarchar(max) NULL,
        [AnhBiaId] uniqueidentifier NULL,
        [NgayBatDau] date NULL,
        [NgayKetThuc] date NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_KeHoach] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_KeHoach_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema15 AS sysname;
    SET @defaultSchema15 = SCHEMA_NAME();
    DECLARE @description15 AS sql_variant;
    SET @description15 = N'Kế hoạch chung (vd chuyến du lịch) gồm nhiều lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach';
    SET @description15 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'Id';
    SET @description15 = N'Tên kế hoạch';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'TieuDe';
    SET @description15 = N'Mô tả';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'MoTa';
    SET @description15 = N'Ảnh bìa (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'AnhBiaId';
    SET @description15 = N'Ngày bắt đầu';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NgayBatDau';
    SET @description15 = N'Ngày kết thúc';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NgayKetThuc';
    SET @description15 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NgayTao';
    SET @description15 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NgayCapNhat';
    SET @description15 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NgayXoa';
    SET @description15 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description15, 'SCHEMA', @defaultSchema15, 'TABLE', N'KeHoach', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [KyKinh] (
        [Id] uniqueidentifier NOT NULL,
        [DoiTuong] tinyint NOT NULL,
        [NgayBatDau] date NOT NULL,
        [NgayKetThuc] date NULL,
        [LuongMau] tinyint NULL,
        [GhiChu] nvarchar(max) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_KyKinh] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_KyKinh_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema16 AS sysname;
    SET @defaultSchema16 = SCHEMA_NAME();
    DECLARE @description16 AS sql_variant;
    SET @description16 = N'Kỳ kinh nguyệt';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh';
    SET @description16 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'Id';
    SET @description16 = N'Theo dõi cho: 1=bản thân, 2=người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'DoiTuong';
    SET @description16 = N'Ngày bắt đầu hành kinh';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NgayBatDau';
    SET @description16 = N'Ngày kết thúc hành kinh';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NgayKetThuc';
    SET @description16 = N'Lượng máu: 1=ít, 2=vừa, 3=nhiều';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'LuongMau';
    SET @description16 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'GhiChu';
    SET @description16 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NgayTao';
    SET @description16 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NgayCapNhat';
    SET @description16 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NgayXoa';
    SET @description16 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description16, 'SCHEMA', @defaultSchema16, 'TABLE', N'KyKinh', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [MaLamMoi] (
        [Id] uniqueidentifier NOT NULL,
        [MaBam] nvarchar(128) NOT NULL,
        [HetHanLuc] datetimeoffset NOT NULL,
        [ThuHoiLuc] datetimeoffset NULL,
        [ThietBiId] uniqueidentifier NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_MaLamMoi] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_MaLamMoi_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema17 AS sysname;
    SET @defaultSchema17 = SCHEMA_NAME();
    DECLARE @description17 AS sql_variant;
    SET @description17 = N'Refresh token để cấp lại access token';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi';
    SET @description17 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'Id';
    SET @description17 = N'Giá trị token đã băm';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'MaBam';
    SET @description17 = N'Thời điểm hết hạn';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'HetHanLuc';
    SET @description17 = N'Thời điểm bị thu hồi';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'ThuHoiLuc';
    SET @description17 = N'Thiết bị sử dụng token';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'ThietBiId';
    SET @description17 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'NgayTao';
    SET @description17 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'NgayCapNhat';
    SET @description17 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'NgayXoa';
    SET @description17 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description17, 'SCHEMA', @defaultSchema17, 'TABLE', N'MaLamMoi', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [NhatKyChuKy] (
        [Id] uniqueidentifier NOT NULL,
        [DoiTuong] tinyint NOT NULL,
        [Ngay] date NOT NULL,
        [TrieuChungJson] nvarchar(max) NULL,
        [TamTrang] nvarchar(50) NULL,
        [GhiChu] nvarchar(max) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_NhatKyChuKy] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_NhatKyChuKy_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema18 AS sysname;
    SET @defaultSchema18 = SCHEMA_NAME();
    DECLARE @description18 AS sql_variant;
    SET @description18 = N'Nhật ký triệu chứng hằng ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy';
    SET @description18 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'Id';
    SET @description18 = N'Theo dõi cho: 1=bản thân, 2=người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'DoiTuong';
    SET @description18 = N'Ngày ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'Ngay';
    SET @description18 = N'Triệu chứng (JSON mảng mã)';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'TrieuChungJson';
    SET @description18 = N'Tâm trạng';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'TamTrang';
    SET @description18 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'GhiChu';
    SET @description18 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'NgayTao';
    SET @description18 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'NgayCapNhat';
    SET @description18 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'NgayXoa';
    SET @description18 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description18, 'SCHEMA', @defaultSchema18, 'TABLE', N'NhatKyChuKy', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TaiKhoan] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [Loai] tinyint NOT NULL,
        [BieuTuong] nvarchar(50) NULL,
        [MauSac] nvarchar(9) NULL,
        [MaTienTe] nvarchar(10) NOT NULL,
        [SoDuBanDau] decimal(19,4) NOT NULL,
        [TinhVaoTong] bit NOT NULL,
        [ThuTu] int NOT NULL,
        [DaLuuTru] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_TaiKhoan] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TaiKhoan_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema19 AS sysname;
    SET @defaultSchema19 = SCHEMA_NAME();
    DECLARE @description19 AS sql_variant;
    SET @description19 = N'Tài khoản / ví tiền';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan';
    SET @description19 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'Id';
    SET @description19 = N'Tên tài khoản, vd Tiền mặt, Vietcombank';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'Ten';
    SET @description19 = N'Loại: 1=tiền mặt, 2=ngân hàng, 3=ví điện tử, 4=thẻ tín dụng, 99=khác';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'Loai';
    SET @description19 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'BieuTuong';
    SET @description19 = N'Màu (hex, vd #FF8800)';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'MauSac';
    SET @description19 = N'Mã tiền tệ của tài khoản';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'MaTienTe';
    SET @description19 = N'Số dư ban đầu';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'SoDuBanDau';
    SET @description19 = N'Có tính vào tổng tài sản không';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'TinhVaoTong';
    SET @description19 = N'Thứ tự sắp xếp';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'ThuTu';
    SET @description19 = N'Đã lưu trữ (ẩn khỏi danh sách)';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'DaLuuTru';
    SET @description19 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'NgayTao';
    SET @description19 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'NgayCapNhat';
    SET @description19 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'NgayXoa';
    SET @description19 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description19, 'SCHEMA', @defaultSchema19, 'TABLE', N'TaiKhoan', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TepTin] (
        [Id] uniqueidentifier NOT NULL,
        [DuongDan] nvarchar(500) NOT NULL,
        [DuongDanThuNho] nvarchar(500) NULL,
        [TenGoc] nvarchar(500) NULL,
        [KieuFile] nvarchar(100) NOT NULL,
        [DungLuong] bigint NOT NULL,
        [ChieuRong] int NULL,
        [ChieuCao] int NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_TepTin] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TepTin_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema20 AS sysname;
    SET @defaultSchema20 = SCHEMA_NAME();
    DECLARE @description20 AS sql_variant;
    SET @description20 = N'File đã upload lên server (ảnh)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin';
    SET @description20 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'Id';
    SET @description20 = N'Đường dẫn lưu trữ tương đối';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'DuongDan';
    SET @description20 = N'Đường dẫn ảnh thu nhỏ';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'DuongDanThuNho';
    SET @description20 = N'Tên file gốc';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'TenGoc';
    SET @description20 = N'Kiểu MIME, vd image/jpeg';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'KieuFile';
    SET @description20 = N'Dung lượng (byte)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'DungLuong';
    SET @description20 = N'Chiều rộng ảnh (px)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'ChieuRong';
    SET @description20 = N'Chiều cao ảnh (px)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'ChieuCao';
    SET @description20 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'NgayTao';
    SET @description20 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'NgayCapNhat';
    SET @description20 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'NgayXoa';
    SET @description20 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description20, 'SCHEMA', @defaultSchema20, 'TABLE', N'TepTin', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [ThanhVienHoiThoai] (
        [Id] uniqueidentifier NOT NULL,
        [HoiThoaiId] uniqueidentifier NOT NULL,
        [ThanhVienId] uniqueidentifier NOT NULL,
        [VaiTro] tinyint NOT NULL,
        [DaDocDenId] uniqueidentifier NULL,
        [DaNhanDenId] uniqueidentifier NULL,
        [TatThongBao] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_ThanhVienHoiThoai] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ThanhVienHoiThoai_HoiThoai_HoiThoaiId] FOREIGN KEY ([HoiThoaiId]) REFERENCES [HoiThoai] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ThanhVienHoiThoai_NguoiDung_ThanhVienId] FOREIGN KEY ([ThanhVienId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema21 AS sysname;
    SET @defaultSchema21 = SCHEMA_NAME();
    DECLARE @description21 AS sql_variant;
    SET @description21 = N'Thành viên hội thoại';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai';
    SET @description21 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'Id';
    SET @description21 = N'Hội thoại';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'HoiThoaiId';
    SET @description21 = N'Thành viên';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'ThanhVienId';
    SET @description21 = N'Vai trò: 1=chủ, 2=thành viên';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'VaiTro';
    SET @description21 = N'Tin nhắn đã đọc gần nhất';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'DaDocDenId';
    SET @description21 = N'Tin nhắn đã nhận gần nhất';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'DaNhanDenId';
    SET @description21 = N'Tắt thông báo';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'TatThongBao';
    SET @description21 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'NgayTao';
    SET @description21 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'NgayCapNhat';
    SET @description21 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description21, 'SCHEMA', @defaultSchema21, 'TABLE', N'ThanhVienHoiThoai', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [ThietBi] (
        [Id] uniqueidentifier NOT NULL,
        [NenTang] tinyint NOT NULL,
        [FcmToken] nvarchar(500) NULL,
        [Ten] nvarchar(500) NULL,
        [PhienBanApp] nvarchar(500) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_ThietBi] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ThietBi_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema22 AS sysname;
    SET @defaultSchema22 = SCHEMA_NAME();
    DECLARE @description22 AS sql_variant;
    SET @description22 = N'Thiết bị đăng nhập - nhận thông báo đẩy';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi';
    SET @description22 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'Id';
    SET @description22 = N'Nền tảng: 1=iOS, 2=Android';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'NenTang';
    SET @description22 = N'FCM token để gửi push';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'FcmToken';
    SET @description22 = N'Tên thiết bị';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'Ten';
    SET @description22 = N'Phiên bản app';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'PhienBanApp';
    SET @description22 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'NgayTao';
    SET @description22 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'NgayCapNhat';
    SET @description22 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'NgayXoa';
    SET @description22 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description22, 'SCHEMA', @defaultSchema22, 'TABLE', N'ThietBi', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [ThongBao] (
        [Id] uniqueidentifier NOT NULL,
        [Loai] tinyint NOT NULL,
        [NguoiTacDongId] uniqueidentifier NULL,
        [TieuDe] nvarchar(200) NOT NULL,
        [NoiDung] nvarchar(max) NULL,
        [DuLieuJson] nvarchar(max) NULL,
        [DaDocLuc] datetimeoffset NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_ThongBao] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ThongBao_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema23 AS sysname;
    SET @defaultSchema23 = SCHEMA_NAME();
    DECLARE @description23 AS sql_variant;
    SET @description23 = N'Thông báo trong app';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao';
    SET @description23 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'Id';
    SET @description23 = N'Loại thông báo';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'Loai';
    SET @description23 = N'Người gây ra thông báo';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NguoiTacDongId';
    SET @description23 = N'Tiêu đề';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'TieuDe';
    SET @description23 = N'Nội dung';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NoiDung';
    SET @description23 = N'Dữ liệu điều hướng (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'DuLieuJson';
    SET @description23 = N'Thời điểm đã đọc';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'DaDocLuc';
    SET @description23 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NgayTao';
    SET @description23 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NgayCapNhat';
    SET @description23 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NgayXoa';
    SET @description23 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description23, 'SCHEMA', @defaultSchema23, 'TABLE', N'ThongBao', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TienTe] (
        [Id] uniqueidentifier NOT NULL,
        [Ma] nvarchar(10) NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [KyHieu] nvarchar(10) NOT NULL,
        [SoThapPhan] tinyint NOT NULL,
        [ViTriKyHieu] tinyint NOT NULL,
        [LaTienChinh] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_TienTe] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TienTe_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema24 AS sysname;
    SET @defaultSchema24 = SCHEMA_NAME();
    DECLARE @description24 AS sql_variant;
    SET @description24 = N'Tiền tệ người dùng cấu hình';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe';
    SET @description24 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'Id';
    SET @description24 = N'Mã ISO 4217, vd VND, USD';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'Ma';
    SET @description24 = N'Tên tiền tệ';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'Ten';
    SET @description24 = N'Ký hiệu, vd ₫, $';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'KyHieu';
    SET @description24 = N'Số chữ số thập phân hiển thị (VND = 0)';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'SoThapPhan';
    SET @description24 = N'Vị trí ký hiệu: 1=sau số, 2=trước số';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'ViTriKyHieu';
    SET @description24 = N'Là tiền tệ chính để quy đổi thống kê';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'LaTienChinh';
    SET @description24 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'NgayTao';
    SET @description24 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'NgayCapNhat';
    SET @description24 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'NgayXoa';
    SET @description24 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description24, 'SCHEMA', @defaultSchema24, 'TABLE', N'TienTe', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TinNhan] (
        [Id] uniqueidentifier NOT NULL,
        [HoiThoaiId] uniqueidentifier NOT NULL,
        [NguoiGuiId] uniqueidentifier NOT NULL,
        [Loai] tinyint NOT NULL,
        [NoiDung] nvarchar(max) NULL,
        [TraLoiTinNhanId] uniqueidentifier NULL,
        [GuiLuc] datetimeoffset NOT NULL,
        [MayChuNhanLuc] datetimeoffset NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_TinNhan] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TinNhan_HoiThoai_HoiThoaiId] FOREIGN KEY ([HoiThoaiId]) REFERENCES [HoiThoai] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_TinNhan_NguoiDung_NguoiGuiId] FOREIGN KEY ([NguoiGuiId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema25 AS sysname;
    SET @defaultSchema25 = SCHEMA_NAME();
    DECLARE @description25 AS sql_variant;
    SET @description25 = N'Tin nhắn';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan';
    SET @description25 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'Id';
    SET @description25 = N'Hội thoại';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'HoiThoaiId';
    SET @description25 = N'Người gửi';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'NguoiGuiId';
    SET @description25 = N'Loại: 1=chữ, 2=ảnh, 3=hệ thống';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'Loai';
    SET @description25 = N'Nội dung';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'NoiDung';
    SET @description25 = N'Trả lời tin nhắn';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'TraLoiTinNhanId';
    SET @description25 = N'Thời điểm gửi trên máy (có thể lúc offline)';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'GuiLuc';
    SET @description25 = N'Thời điểm server nhận';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'MayChuNhanLuc';
    SET @description25 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'NgayTao';
    SET @description25 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'NgayCapNhat';
    SET @description25 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description25, 'SCHEMA', @defaultSchema25, 'TABLE', N'TinNhan', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TyGia] (
        [Id] uniqueidentifier NOT NULL,
        [MaTienNguon] nvarchar(10) NOT NULL,
        [MaTienDich] nvarchar(10) NOT NULL,
        [TyGia] decimal(28,10) NOT NULL,
        [NgayApDung] date NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_TyGia] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TyGia_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema26 AS sysname;
    SET @defaultSchema26 = SCHEMA_NAME();
    DECLARE @description26 AS sql_variant;
    SET @description26 = N'Tỷ giá nhập tay theo ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia';
    SET @description26 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'Id';
    SET @description26 = N'Mã tiền tệ nguồn';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'MaTienNguon';
    SET @description26 = N'Mã tiền tệ đích';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'MaTienDich';
    SET @description26 = N'1 đơn vị nguồn = Rate đơn vị đích';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'TyGia';
    SET @description26 = N'Ngày bắt đầu áp dụng';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'NgayApDung';
    SET @description26 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'NgayTao';
    SET @description26 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'NgayCapNhat';
    SET @description26 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'NgayXoa';
    SET @description26 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description26, 'SCHEMA', @defaultSchema26, 'TABLE', N'TyGia', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [ChucNang] (
        [Id] uniqueidentifier NOT NULL,
        [PhanHeId] uniqueidentifier NOT NULL,
        [ChucNangChaId] uniqueidentifier NULL,
        [Ma] nvarchar(100) NOT NULL,
        [Ten] nvarchar(500) NOT NULL,
        [DuongDanManHinh] nvarchar(500) NULL,
        [BieuTuong] nvarchar(500) NULL,
        [ThuTu] int NOT NULL,
        [HienMenu] bit NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_ChucNang] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ChucNang_ChucNang_ChucNangChaId] FOREIGN KEY ([ChucNangChaId]) REFERENCES [ChucNang] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ChucNang_PhanHe_PhanHeId] FOREIGN KEY ([PhanHeId]) REFERENCES [PhanHe] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema27 AS sysname;
    SET @defaultSchema27 = SCHEMA_NAME();
    DECLARE @description27 AS sql_variant;
    SET @description27 = N'Chức năng / quyền (cũng là mục menu nếu IsShow)';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang';
    SET @description27 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'Id';
    SET @description27 = N'Phân hệ';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'PhanHeId';
    SET @description27 = N'Chức năng cha (menu nhiều cấp)';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'ChucNangChaId';
    SET @description27 = N'Mã chức năng duy nhất, vd QUAN_TRI.VAI_TRO';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'Ma';
    SET @description27 = N'Tên chức năng';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'Ten';
    SET @description27 = N'Đường dẫn màn hình trên app, vd /admin/roles';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'DuongDanManHinh';
    SET @description27 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'BieuTuong';
    SET @description27 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'ThuTu';
    SET @description27 = N'Hiện trên menu';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'HienMenu';
    SET @description27 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'NgayTao';
    SET @description27 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'NgayCapNhat';
    SET @description27 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description27, 'SCHEMA', @defaultSchema27, 'TABLE', N'ChucNang', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [NguoiDungVaiTro] (
        [Id] uniqueidentifier NOT NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        [VaiTroId] uniqueidentifier NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_NguoiDungVaiTro] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_NguoiDungVaiTro_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_NguoiDungVaiTro_VaiTro_VaiTroId] FOREIGN KEY ([VaiTroId]) REFERENCES [VaiTro] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema28 AS sysname;
    SET @defaultSchema28 = SCHEMA_NAME();
    DECLARE @description28 AS sql_variant;
    SET @description28 = N'Vai trò của người dùng';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro';
    SET @description28 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'Id';
    SET @description28 = N'Người dùng';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'NguoiDungId';
    SET @description28 = N'Vai trò';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'VaiTroId';
    SET @description28 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'NgayTao';
    SET @description28 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'NgayCapNhat';
    SET @description28 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description28, 'SCHEMA', @defaultSchema28, 'TABLE', N'NguoiDungVaiTro', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [BinhLuan] (
        [Id] uniqueidentifier NOT NULL,
        [BaiVietId] uniqueidentifier NOT NULL,
        [TacGiaId] uniqueidentifier NOT NULL,
        [BinhLuanChaId] uniqueidentifier NULL,
        [NoiDung] nvarchar(max) NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_BinhLuan] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BinhLuan_BaiViet_BaiVietId] FOREIGN KEY ([BaiVietId]) REFERENCES [BaiViet] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_BinhLuan_BinhLuan_BinhLuanChaId] FOREIGN KEY ([BinhLuanChaId]) REFERENCES [BinhLuan] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_BinhLuan_NguoiDung_TacGiaId] FOREIGN KEY ([TacGiaId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema29 AS sysname;
    SET @defaultSchema29 = SCHEMA_NAME();
    DECLARE @description29 AS sql_variant;
    SET @description29 = N'Bình luận';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan';
    SET @description29 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'Id';
    SET @description29 = N'Bài viết';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'BaiVietId';
    SET @description29 = N'Người bình luận';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'TacGiaId';
    SET @description29 = N'Bình luận cha (trả lời 1 cấp)';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'BinhLuanChaId';
    SET @description29 = N'Nội dung';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'NoiDung';
    SET @description29 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'NgayTao';
    SET @description29 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'NgayCapNhat';
    SET @description29 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description29, 'SCHEMA', @defaultSchema29, 'TABLE', N'BinhLuan', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [NguoiXemBaiViet] (
        [Id] uniqueidentifier NOT NULL,
        [BaiVietId] uniqueidentifier NOT NULL,
        [NguoiXemId] uniqueidentifier NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_NguoiXemBaiViet] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_NguoiXemBaiViet_BaiViet_BaiVietId] FOREIGN KEY ([BaiVietId]) REFERENCES [BaiViet] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema30 AS sysname;
    SET @defaultSchema30 = SCHEMA_NAME();
    DECLARE @description30 AS sql_variant;
    SET @description30 = N'Người được xem bài viết (khi quyền xem = chọn người)';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet';
    SET @description30 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'Id';
    SET @description30 = N'Bài viết';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'BaiVietId';
    SET @description30 = N'Người được xem';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'NguoiXemId';
    SET @description30 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'NgayTao';
    SET @description30 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'NgayCapNhat';
    SET @description30 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description30, 'SCHEMA', @defaultSchema30, 'TABLE', N'NguoiXemBaiViet', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [TagBaiViet] (
        [Id] uniqueidentifier NOT NULL,
        [BaiVietId] uniqueidentifier NOT NULL,
        [NguoiDuocTagId] uniqueidentifier NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_TagBaiViet] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_TagBaiViet_BaiViet_BaiVietId] FOREIGN KEY ([BaiVietId]) REFERENCES [BaiViet] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema31 AS sysname;
    SET @defaultSchema31 = SCHEMA_NAME();
    DECLARE @description31 AS sql_variant;
    SET @description31 = N'Bạn bè được tag trong bài viết';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet';
    SET @description31 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'Id';
    SET @description31 = N'Bài viết';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'BaiVietId';
    SET @description31 = N'Người được tag';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'NguoiDuocTagId';
    SET @description31 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'NgayTao';
    SET @description31 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'NgayCapNhat';
    SET @description31 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description31, 'SCHEMA', @defaultSchema31, 'TABLE', N'TagBaiViet', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [BacGiaDien] (
        [Id] uniqueidentifier NOT NULL,
        [BangGiaId] uniqueidentifier NOT NULL,
        [Bac] int NOT NULL,
        [TuKwh] int NOT NULL,
        [DenKwh] int NULL,
        [DonGia] decimal(19,4) NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_BacGiaDien] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BacGiaDien_BangGiaDien_BangGiaId] FOREIGN KEY ([BangGiaId]) REFERENCES [BangGiaDien] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_BacGiaDien_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema32 AS sysname;
    SET @defaultSchema32 = SCHEMA_NAME();
    DECLARE @description32 AS sql_variant;
    SET @description32 = N'Một bậc trong bảng giá điện';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien';
    SET @description32 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'Id';
    SET @description32 = N'Bảng giá';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'BangGiaId';
    SET @description32 = N'Thứ tự bậc (1, 2, 3...)';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'Bac';
    SET @description32 = N'Từ kWh (bao gồm)';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'TuKwh';
    SET @description32 = N'Đến kWh (bao gồm), NULL = không giới hạn';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'DenKwh';
    SET @description32 = N'Đơn giá (đồng/kWh)';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'DonGia';
    SET @description32 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'NgayTao';
    SET @description32 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'NgayCapNhat';
    SET @description32 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'NgayXoa';
    SET @description32 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description32, 'SCHEMA', @defaultSchema32, 'TABLE', N'BacGiaDien', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [HoaDonDien] (
        [Id] uniqueidentifier NOT NULL,
        [BangGiaId] uniqueidentifier NOT NULL,
        [Ky] date NOT NULL,
        [ChiSoCu] int NULL,
        [ChiSoMoi] int NULL,
        [SoKwh] int NOT NULL,
        [SoTien] decimal(19,4) NOT NULL,
        [ChiTietJson] nvarchar(max) NULL,
        [GiaoDichId] uniqueidentifier NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_HoaDonDien] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_HoaDonDien_BangGiaDien_BangGiaId] FOREIGN KEY ([BangGiaId]) REFERENCES [BangGiaDien] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_HoaDonDien_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema33 AS sysname;
    SET @defaultSchema33 = SCHEMA_NAME();
    DECLARE @description33 AS sql_variant;
    SET @description33 = N'Lịch sử tiền điện từng kỳ';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien';
    SET @description33 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'Id';
    SET @description33 = N'Bảng giá đã dùng';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'BangGiaId';
    SET @description33 = N'Kỳ (ngày đầu tháng)';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'Ky';
    SET @description33 = N'Chỉ số cũ';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'ChiSoCu';
    SET @description33 = N'Chỉ số mới';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'ChiSoMoi';
    SET @description33 = N'Số kWh tiêu thụ';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'SoKwh';
    SET @description33 = N'Số tiền (đã gồm VAT, phí)';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'SoTien';
    SET @description33 = N'Chi tiết từng bậc (JSON)';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'ChiTietJson';
    SET @description33 = N'Giao dịch đã tạo từ hoá đơn này';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'GiaoDichId';
    SET @description33 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'NgayTao';
    SET @description33 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'NgayCapNhat';
    SET @description33 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'NgayXoa';
    SET @description33 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description33, 'SCHEMA', @defaultSchema33, 'TABLE', N'HoaDonDien', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [LichSuHu] (
        [Id] uniqueidentifier NOT NULL,
        [HuTietKiemId] uniqueidentifier NOT NULL,
        [TaiKhoanId] uniqueidentifier NULL,
        [SoTien] decimal(19,4) NOT NULL,
        [GhiChu] nvarchar(max) NULL,
        [ThoiDiem] datetimeoffset NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_LichSuHu] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_LichSuHu_HuTietKiem_HuTietKiemId] FOREIGN KEY ([HuTietKiemId]) REFERENCES [HuTietKiem] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_LichSuHu_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema34 AS sysname;
    SET @defaultSchema34 = SCHEMA_NAME();
    DECLARE @description34 AS sql_variant;
    SET @description34 = N'Lịch sử nạp / rút hũ tiết kiệm';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu';
    SET @description34 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'Id';
    SET @description34 = N'Hũ tiết kiệm';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'HuTietKiemId';
    SET @description34 = N'Tài khoản lấy tiền / nhận tiền';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'TaiKhoanId';
    SET @description34 = N'Số tiền: dương = nạp, âm = rút';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'SoTien';
    SET @description34 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'GhiChu';
    SET @description34 = N'Thời điểm nạp/rút';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'ThoiDiem';
    SET @description34 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'NgayTao';
    SET @description34 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'NgayCapNhat';
    SET @description34 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'NgayXoa';
    SET @description34 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description34, 'SCHEMA', @defaultSchema34, 'TABLE', N'LichSuHu', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [LichTrinh] (
        [Id] uniqueidentifier NOT NULL,
        [TieuDe] nvarchar(200) NOT NULL,
        [BatDau] datetimeoffset NOT NULL,
        [KetThuc] datetimeoffset NULL,
        [CaNgay] bit NOT NULL,
        [DiaDiem] nvarchar(500) NULL,
        [ViDo] float NULL,
        [KinhDo] float NULL,
        [GhiChu] nvarchar(max) NULL,
        [PhanLoai] tinyint NOT NULL,
        [MauSac] nvarchar(9) NULL,
        [QuyTacLap] nvarchar(max) NULL,
        [LapDen] date NULL,
        [NhacTruocPhut] int NULL,
        [KeHoachId] uniqueidentifier NULL,
        [AnhBiaId] uniqueidentifier NULL,
        [ChiPhiDuKien] decimal(19,4) NULL,
        [MaTienTe] nvarchar(10) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_LichTrinh] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_LichTrinh_KeHoach_KeHoachId] FOREIGN KEY ([KeHoachId]) REFERENCES [KeHoach] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_LichTrinh_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema35 AS sysname;
    SET @defaultSchema35 = SCHEMA_NAME();
    DECLARE @description35 AS sql_variant;
    SET @description35 = N'Lịch trình / sự kiện';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh';
    SET @description35 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'Id';
    SET @description35 = N'Tiêu đề';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'TieuDe';
    SET @description35 = N'Bắt đầu';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'BatDau';
    SET @description35 = N'Kết thúc';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'KetThuc';
    SET @description35 = N'Cả ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'CaNgay';
    SET @description35 = N'Địa điểm';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'DiaDiem';
    SET @description35 = N'Vĩ độ';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'ViDo';
    SET @description35 = N'Kinh độ';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'KinhDo';
    SET @description35 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'GhiChu';
    SET @description35 = N'Loại: 1=đi chơi, 2=công việc, 99=khác';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'PhanLoai';
    SET @description35 = N'Màu (hex)';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'MauSac';
    SET @description35 = N'Quy tắc lặp RRULE, NULL = không lặp';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'QuyTacLap';
    SET @description35 = N'Lặp đến ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'LapDen';
    SET @description35 = N'Nhắc trước bao nhiêu phút, NULL = không nhắc';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'NhacTruocPhut';
    SET @description35 = N'Thuộc kế hoạch chung';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'KeHoachId';
    SET @description35 = N'Ảnh bìa (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'AnhBiaId';
    SET @description35 = N'Chi phí dự kiến';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'ChiPhiDuKien';
    SET @description35 = N'Mã tiền tệ của chi phí';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'MaTienTe';
    SET @description35 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'NgayTao';
    SET @description35 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'NgayCapNhat';
    SET @description35 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'NgayXoa';
    SET @description35 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description35, 'SCHEMA', @defaultSchema35, 'TABLE', N'LichTrinh', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [ThanhVienKeHoach] (
        [Id] uniqueidentifier NOT NULL,
        [KeHoachId] uniqueidentifier NOT NULL,
        [ThanhVienId] uniqueidentifier NOT NULL,
        [VaiTro] tinyint NOT NULL,
        [TrangThai] tinyint NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_ThanhVienKeHoach] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_ThanhVienKeHoach_KeHoach_KeHoachId] FOREIGN KEY ([KeHoachId]) REFERENCES [KeHoach] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_ThanhVienKeHoach_NguoiDung_ThanhVienId] FOREIGN KEY ([ThanhVienId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema36 AS sysname;
    SET @defaultSchema36 = SCHEMA_NAME();
    DECLARE @description36 AS sql_variant;
    SET @description36 = N'Thành viên kế hoạch chung';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach';
    SET @description36 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'Id';
    SET @description36 = N'Kế hoạch';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'KeHoachId';
    SET @description36 = N'Thành viên';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'ThanhVienId';
    SET @description36 = N'Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'VaiTro';
    SET @description36 = N'Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'TrangThai';
    SET @description36 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'NgayTao';
    SET @description36 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'NgayCapNhat';
    SET @description36 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description36, 'SCHEMA', @defaultSchema36, 'TABLE', N'ThanhVienKeHoach', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [GiaoDich] (
        [Id] uniqueidentifier NOT NULL,
        [Loai] tinyint NOT NULL,
        [SoTien] decimal(19,4) NOT NULL,
        [MaTienTe] nvarchar(10) NOT NULL,
        [TaiKhoanId] uniqueidentifier NOT NULL,
        [TaiKhoanNhanId] uniqueidentifier NULL,
        [SoTienNhan] decimal(19,4) NULL,
        [DanhMucId] uniqueidentifier NULL,
        [ThoiDiem] datetimeoffset NOT NULL,
        [GhiChu] nvarchar(max) NULL,
        [LichTrinhId] uniqueidentifier NULL,
        [HuTietKiemId] uniqueidentifier NULL,
        [GiaoDichDinhKyId] uniqueidentifier NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_GiaoDich] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_GiaoDich_DanhMuc_DanhMucId] FOREIGN KEY ([DanhMucId]) REFERENCES [DanhMuc] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_GiaoDich_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_GiaoDich_TaiKhoan_TaiKhoanId] FOREIGN KEY ([TaiKhoanId]) REFERENCES [TaiKhoan] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_GiaoDich_TaiKhoan_TaiKhoanNhanId] FOREIGN KEY ([TaiKhoanNhanId]) REFERENCES [TaiKhoan] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema37 AS sysname;
    SET @defaultSchema37 = SCHEMA_NAME();
    DECLARE @description37 AS sql_variant;
    SET @description37 = N'Giao dịch thu / chi / chuyển khoản';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich';
    SET @description37 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'Id';
    SET @description37 = N'Loại: 1=chi, 2=thu, 3=chuyển khoản';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'Loai';
    SET @description37 = N'Số tiền (luôn dương) theo tiền tệ của tài khoản nguồn';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'SoTien';
    SET @description37 = N'Mã tiền tệ của số tiền';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'MaTienTe';
    SET @description37 = N'Tài khoản nguồn';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'TaiKhoanId';
    SET @description37 = N'Tài khoản nhận (chỉ khi chuyển khoản)';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'TaiKhoanNhanId';
    SET @description37 = N'Số tiền tài khoản nhận được (khi khác tiền tệ)';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'SoTienNhan';
    SET @description37 = N'Danh mục (NULL khi chuyển khoản)';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'DanhMucId';
    SET @description37 = N'Thời điểm phát sinh';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'ThoiDiem';
    SET @description37 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'GhiChu';
    SET @description37 = N'Gắn với lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'LichTrinhId';
    SET @description37 = N'Gắn với hũ tiết kiệm';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'HuTietKiemId';
    SET @description37 = N'Sinh ra từ giao dịch định kỳ';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'GiaoDichDinhKyId';
    SET @description37 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'NgayTao';
    SET @description37 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'NgayCapNhat';
    SET @description37 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'NgayXoa';
    SET @description37 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description37, 'SCHEMA', @defaultSchema37, 'TABLE', N'GiaoDich', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [AnhDinhKem] (
        [Id] uniqueidentifier NOT NULL,
        [LoaiDoiTuong] tinyint NOT NULL,
        [DoiTuongId] uniqueidentifier NOT NULL,
        [TepTinId] uniqueidentifier NOT NULL,
        [ChuThich] nvarchar(500) NULL,
        [ThuTu] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_AnhDinhKem] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AnhDinhKem_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_AnhDinhKem_TepTin_TepTinId] FOREIGN KEY ([TepTinId]) REFERENCES [TepTin] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema38 AS sysname;
    SET @defaultSchema38 = SCHEMA_NAME();
    DECLARE @description38 AS sql_variant;
    SET @description38 = N'Ảnh đính kèm cho giao dịch / lịch trình / bài viết / tin nhắn...';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem';
    SET @description38 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'Id';
    SET @description38 = N'Loại đối tượng: 1=giao dịch, 2=lịch trình, 3=bài viết, 4=tin nhắn, 5=hoá đơn điện, 6=hũ';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'LoaiDoiTuong';
    SET @description38 = N'Id đối tượng sở hữu ảnh';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'DoiTuongId';
    SET @description38 = N'File (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'TepTinId';
    SET @description38 = N'Chú thích ảnh';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'ChuThich';
    SET @description38 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'ThuTu';
    SET @description38 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'NgayTao';
    SET @description38 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'NgayCapNhat';
    SET @description38 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'NgayXoa';
    SET @description38 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description38, 'SCHEMA', @defaultSchema38, 'TABLE', N'AnhDinhKem', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [VaiTroChucNang] (
        [Id] uniqueidentifier NOT NULL,
        [VaiTroId] uniqueidentifier NOT NULL,
        [ChucNangId] uniqueidentifier NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_VaiTroChucNang] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_VaiTroChucNang_ChucNang_ChucNangId] FOREIGN KEY ([ChucNangId]) REFERENCES [ChucNang] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_VaiTroChucNang_VaiTro_VaiTroId] FOREIGN KEY ([VaiTroId]) REFERENCES [VaiTro] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema39 AS sysname;
    SET @defaultSchema39 = SCHEMA_NAME();
    DECLARE @description39 AS sql_variant;
    SET @description39 = N'Chức năng được cấp cho vai trò';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang';
    SET @description39 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'Id';
    SET @description39 = N'Vai trò';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'VaiTroId';
    SET @description39 = N'Chức năng';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'ChucNangId';
    SET @description39 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'NgayTao';
    SET @description39 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'NgayCapNhat';
    SET @description39 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description39, 'SCHEMA', @defaultSchema39, 'TABLE', N'VaiTroChucNang', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [AnhLichTrinh] (
        [Id] uniqueidentifier NOT NULL,
        [LichTrinhId] uniqueidentifier NOT NULL,
        [NgayLanLap] date NULL,
        [TepTinId] uniqueidentifier NOT NULL,
        [NguoiThemId] uniqueidentifier NOT NULL,
        [ChuThich] nvarchar(500) NULL,
        [ThuTu] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_AnhLichTrinh] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_AnhLichTrinh_LichTrinh_LichTrinhId] FOREIGN KEY ([LichTrinhId]) REFERENCES [LichTrinh] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_AnhLichTrinh_TepTin_TepTinId] FOREIGN KEY ([TepTinId]) REFERENCES [TepTin] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema40 AS sysname;
    SET @defaultSchema40 = SCHEMA_NAME();
    DECLARE @description40 AS sql_variant;
    SET @description40 = N'Ảnh album của lịch trình (theo từng lần lặp)';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh';
    SET @description40 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'Id';
    SET @description40 = N'Lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'LichTrinhId';
    SET @description40 = N'Ngày của lần lặp (NULL nếu lịch không lặp)';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'NgayLanLap';
    SET @description40 = N'File ảnh (StoredFiles.Id)';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'TepTinId';
    SET @description40 = N'Người thêm ảnh';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'NguoiThemId';
    SET @description40 = N'Chú thích';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'ChuThich';
    SET @description40 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'ThuTu';
    SET @description40 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'NgayTao';
    SET @description40 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'NgayCapNhat';
    SET @description40 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description40, 'SCHEMA', @defaultSchema40, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE TABLE [NguoiThamGiaLichTrinh] (
        [Id] uniqueidentifier NOT NULL,
        [LichTrinhId] uniqueidentifier NOT NULL,
        [NguoiThamGiaId] uniqueidentifier NOT NULL,
        [TrangThai] tinyint NOT NULL,
        [VaiTro] tinyint NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_NguoiThamGiaLichTrinh] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_NguoiThamGiaLichTrinh_LichTrinh_LichTrinhId] FOREIGN KEY ([LichTrinhId]) REFERENCES [LichTrinh] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_NguoiThamGiaLichTrinh_NguoiDung_NguoiThamGiaId] FOREIGN KEY ([NguoiThamGiaId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema41 AS sysname;
    SET @defaultSchema41 = SCHEMA_NAME();
    DECLARE @description41 AS sql_variant;
    SET @description41 = N'Người tham gia lịch trình chung';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh';
    SET @description41 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'Id';
    SET @description41 = N'Lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'LichTrinhId';
    SET @description41 = N'Người tham gia';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'NguoiThamGiaId';
    SET @description41 = N'Trạng thái: 1=đã mời, 2=đồng ý, 3=từ chối';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'TrangThai';
    SET @description41 = N'Vai trò: 1=chủ, 2=được sửa, 3=chỉ xem';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'VaiTro';
    SET @description41 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'NgayTao';
    SET @description41 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'NgayCapNhat';
    SET @description41 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description41, 'SCHEMA', @defaultSchema41, 'TABLE', N'NguoiThamGiaLichTrinh', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhDinhKem_LoaiDoiTuong_DoiTuongId] ON [AnhDinhKem] ([LoaiDoiTuong], [DoiTuongId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhDinhKem_NguoiDungId_NgayCapNhat] ON [AnhDinhKem] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhDinhKem_TepTinId] ON [AnhDinhKem] ([TepTinId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhLichTrinh_LichTrinhId_NgayLanLap] ON [AnhLichTrinh] ([LichTrinhId], [NgayLanLap]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhLichTrinh_NgayCapNhat] ON [AnhLichTrinh] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_AnhLichTrinh_TepTinId] ON [AnhLichTrinh] ([TepTinId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_BacGiaDien_BangGiaId_Bac] ON [BacGiaDien] ([BangGiaId], [Bac]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BacGiaDien_NguoiDungId_NgayCapNhat] ON [BacGiaDien] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BaiViet_NgayCapNhat] ON [BaiViet] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BaiViet_TacGiaId_NgayTao] ON [BaiViet] ([TacGiaId], [NgayTao]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BanBe_NgayCapNhat] ON [BanBe] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BanBe_NguoiDuocMoiId_TrangThai] ON [BanBe] ([NguoiDuocMoiId], [TrangThai]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_BanBe_NguoiMoiId_NguoiDuocMoiId] ON [BanBe] ([NguoiMoiId], [NguoiDuocMoiId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BangGiaDien_NguoiDungId_NgayCapNhat] ON [BangGiaDien] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BinhLuan_BaiVietId_NgayTao] ON [BinhLuan] ([BaiVietId], [NgayTao]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BinhLuan_BinhLuanChaId] ON [BinhLuan] ([BinhLuanChaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BinhLuan_NgayCapNhat] ON [BinhLuan] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_BinhLuan_TacGiaId] ON [BinhLuan] ([TacGiaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_CaiDat_NguoiDungId] ON [CaiDat] ([NguoiDungId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_CaiDat_NguoiDungId_NgayCapNhat] ON [CaiDat] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_CamXuc_LoaiDoiTuong_DoiTuongId_NguoiTuongTacId] ON [CamXuc] ([LoaiDoiTuong], [DoiTuongId], [NguoiTuongTacId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_CamXuc_NgayCapNhat] ON [CamXuc] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_CamXuc_NguoiTuongTacId] ON [CamXuc] ([NguoiTuongTacId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_CauHinhChuKy_NguoiDungId_DoiTuong] ON [CauHinhChuKy] ([NguoiDungId], [DoiTuong]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_CauHinhChuKy_NguoiDungId_NgayCapNhat] ON [CauHinhChuKy] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ChucNang_ChucNangChaId] ON [ChucNang] ([ChucNangChaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_ChucNang_Ma] ON [ChucNang] ([Ma]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ChucNang_NgayCapNhat] ON [ChucNang] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ChucNang_PhanHeId] ON [ChucNang] ([PhanHeId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_DanhMuc_DanhMucChaId] ON [DanhMuc] ([DanhMucChaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_DanhMuc_NguoiDungId_Loai_DanhMucChaId] ON [DanhMuc] ([NguoiDungId], [Loai], [DanhMucChaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_DanhMuc_NguoiDungId_NgayCapNhat] ON [DanhMuc] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_DemNgayYeu_NguoiDungId] ON [DemNgayYeu] ([NguoiDungId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_DemNgayYeu_NguoiDungId_NgayCapNhat] ON [DemNgayYeu] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_DinhMuc_NguoiDungId_NgayCapNhat] ON [DinhMuc] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_DanhMucId] ON [GiaoDich] ([DanhMucId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_LichTrinhId] ON [GiaoDich] ([LichTrinhId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_NguoiDungId_DanhMucId_ThoiDiem] ON [GiaoDich] ([NguoiDungId], [DanhMucId], [ThoiDiem]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_NguoiDungId_NgayCapNhat] ON [GiaoDich] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_NguoiDungId_TaiKhoanId_ThoiDiem] ON [GiaoDich] ([NguoiDungId], [TaiKhoanId], [ThoiDiem]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_NguoiDungId_ThoiDiem] ON [GiaoDich] ([NguoiDungId], [ThoiDiem]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_TaiKhoanId] ON [GiaoDich] ([TaiKhoanId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDich_TaiKhoanNhanId] ON [GiaoDich] ([TaiKhoanNhanId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_GiaoDichDinhKy_NguoiDungId_NgayCapNhat] ON [GiaoDichDinhKy] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HoaDonDien_BangGiaId] ON [HoaDonDien] ([BangGiaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HoaDonDien_NguoiDungId_Ky] ON [HoaDonDien] ([NguoiDungId], [Ky]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HoaDonDien_NguoiDungId_NgayCapNhat] ON [HoaDonDien] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HoiThoai_NgayCapNhat] ON [HoiThoai] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HoiThoai_TinNhanCuoiLuc] ON [HoiThoai] ([TinNhanCuoiLuc]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_HuTietKiem_NguoiDungId_NgayCapNhat] ON [HuTietKiem] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_KeHoach_NguoiDungId_NgayCapNhat] ON [KeHoach] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_KyKinh_NguoiDungId_DoiTuong_NgayBatDau] ON [KyKinh] ([NguoiDungId], [DoiTuong], [NgayBatDau]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_KyKinh_NguoiDungId_NgayCapNhat] ON [KyKinh] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_LichSuHu_HuTietKiemId_ThoiDiem] ON [LichSuHu] ([HuTietKiemId], [ThoiDiem]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_LichSuHu_NguoiDungId_NgayCapNhat] ON [LichSuHu] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_LichTrinh_KeHoachId] ON [LichTrinh] ([KeHoachId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_LichTrinh_NguoiDungId_BatDau] ON [LichTrinh] ([NguoiDungId], [BatDau]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_LichTrinh_NguoiDungId_NgayCapNhat] ON [LichTrinh] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE UNIQUE INDEX [IX_MaLamMoi_MaBam] ON [MaLamMoi] ([MaBam]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_MaLamMoi_NguoiDungId_NgayCapNhat] ON [MaLamMoi] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NguoiDung_Email] ON [NguoiDung] ([Email]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiDung_NgayCapNhat] ON [NguoiDung] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NguoiDung_TenDangNhap] ON [NguoiDung] ([TenDangNhap]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiDungVaiTro_NgayCapNhat] ON [NguoiDungVaiTro] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NguoiDungVaiTro_NguoiDungId_VaiTroId] ON [NguoiDungVaiTro] ([NguoiDungId], [VaiTroId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiDungVaiTro_VaiTroId] ON [NguoiDungVaiTro] ([VaiTroId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NguoiThamGiaLichTrinh_LichTrinhId_NguoiThamGiaId] ON [NguoiThamGiaLichTrinh] ([LichTrinhId], [NguoiThamGiaId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiThamGiaLichTrinh_NgayCapNhat] ON [NguoiThamGiaLichTrinh] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiThamGiaLichTrinh_NguoiThamGiaId] ON [NguoiThamGiaLichTrinh] ([NguoiThamGiaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NguoiXemBaiViet_BaiVietId_NguoiXemId] ON [NguoiXemBaiViet] ([BaiVietId], [NguoiXemId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiXemBaiViet_NgayCapNhat] ON [NguoiXemBaiViet] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NguoiXemBaiViet_NguoiXemId] ON [NguoiXemBaiViet] ([NguoiXemId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_NhatKyChuKy_NguoiDungId_DoiTuong_Ngay] ON [NhatKyChuKy] ([NguoiDungId], [DoiTuong], [Ngay]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_NhatKyChuKy_NguoiDungId_NgayCapNhat] ON [NhatKyChuKy] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_PhanHe_Ma] ON [PhanHe] ([Ma]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_PhanHe_NgayCapNhat] ON [PhanHe] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_TagBaiViet_BaiVietId_NguoiDuocTagId] ON [TagBaiViet] ([BaiVietId], [NguoiDuocTagId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TagBaiViet_NgayCapNhat] ON [TagBaiViet] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TaiKhoan_NguoiDungId_NgayCapNhat] ON [TaiKhoan] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TepTin_NguoiDungId_NgayCapNhat] ON [TepTin] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_ThanhVienHoiThoai_HoiThoaiId_ThanhVienId] ON [ThanhVienHoiThoai] ([HoiThoaiId], [ThanhVienId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThanhVienHoiThoai_NgayCapNhat] ON [ThanhVienHoiThoai] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThanhVienHoiThoai_ThanhVienId] ON [ThanhVienHoiThoai] ([ThanhVienId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_ThanhVienKeHoach_KeHoachId_ThanhVienId] ON [ThanhVienKeHoach] ([KeHoachId], [ThanhVienId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThanhVienKeHoach_NgayCapNhat] ON [ThanhVienKeHoach] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThanhVienKeHoach_ThanhVienId] ON [ThanhVienKeHoach] ([ThanhVienId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThietBi_NguoiDungId_NgayCapNhat] ON [ThietBi] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThongBao_NguoiDungId_DaDocLuc] ON [ThongBao] ([NguoiDungId], [DaDocLuc]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_ThongBao_NguoiDungId_NgayCapNhat] ON [ThongBao] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_TienTe_NguoiDungId_Ma] ON [TienTe] ([NguoiDungId], [Ma]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TienTe_NguoiDungId_NgayCapNhat] ON [TienTe] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TinNhan_HoiThoaiId_MayChuNhanLuc] ON [TinNhan] ([HoiThoaiId], [MayChuNhanLuc]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TinNhan_NgayCapNhat] ON [TinNhan] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TinNhan_NguoiGuiId] ON [TinNhan] ([NguoiGuiId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_TyGia_NguoiDungId_MaTienNguon_MaTienDich_NgayApDung] ON [TyGia] ([NguoiDungId], [MaTienNguon], [MaTienDich], [NgayApDung]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_TyGia_NguoiDungId_NgayCapNhat] ON [TyGia] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_VaiTro_Ma] ON [VaiTro] ([Ma]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_VaiTro_NgayCapNhat] ON [VaiTro] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_VaiTroChucNang_ChucNangId] ON [VaiTroChucNang] ([ChucNangId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    CREATE INDEX [IX_VaiTroChucNang_NgayCapNhat] ON [VaiTroChucNang] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    EXEC(N'CREATE UNIQUE INDEX [IX_VaiTroChucNang_VaiTroId_ChucNangId] ON [VaiTroChucNang] ([VaiTroId], [ChucNangId]) WHERE [NgayXoa] IS NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120052710_KhoiTao'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120052710_KhoiTao', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120065632_CaiDatTaiKhoanMacDinh'
)
BEGIN
    ALTER TABLE [CaiDat] ADD [NhoTaiKhoanLanTruoc] bit NOT NULL DEFAULT CAST(0 AS bit);
    DECLARE @defaultSchema42 AS sysname;
    SET @defaultSchema42 = SCHEMA_NAME();
    DECLARE @description42 AS sql_variant;
    SET @description42 = N'Tự chọn tài khoản đã dùng ở giao dịch trước';
    EXEC sp_addextendedproperty 'MS_Description', @description42, 'SCHEMA', @defaultSchema42, 'TABLE', N'CaiDat', 'COLUMN', N'NhoTaiKhoanLanTruoc';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120065632_CaiDatTaiKhoanMacDinh'
)
BEGIN
    ALTER TABLE [CaiDat] ADD [TaiKhoanMacDinhId] uniqueidentifier NULL;
    DECLARE @defaultSchema43 AS sysname;
    SET @defaultSchema43 = SCHEMA_NAME();
    DECLARE @description43 AS sql_variant;
    SET @description43 = N'Tài khoản/ví mặc định khi thêm giao dịch (NULL = tài khoản đầu tiên)';
    EXEC sp_addextendedproperty 'MS_Description', @description43, 'SCHEMA', @defaultSchema43, 'TABLE', N'CaiDat', 'COLUMN', N'TaiKhoanMacDinhId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120065632_CaiDatTaiKhoanMacDinh'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120065632_CaiDatTaiKhoanMacDinh', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070025_LichTrinhChiTiet'
)
BEGIN
    CREATE TABLE [LichTrinhChiTiet] (
        [Id] uniqueidentifier NOT NULL,
        [LichTrinhId] uniqueidentifier NOT NULL,
        [NgayLanLap] date NULL,
        [GioBatDau] time NOT NULL,
        [GioKetThuc] time NULL,
        [TieuDe] nvarchar(200) NOT NULL,
        [DiaDiem] nvarchar(500) NULL,
        [GhiChu] nvarchar(max) NULL,
        [ChiPhi] decimal(19,4) NULL,
        [DaXong] bit NOT NULL,
        [BieuTuong] nvarchar(50) NULL,
        [ThuTu] int NOT NULL,
        [NguoiThemId] uniqueidentifier NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_LichTrinhChiTiet] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_LichTrinhChiTiet_LichTrinh_LichTrinhId] FOREIGN KEY ([LichTrinhId]) REFERENCES [LichTrinh] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema44 AS sysname;
    SET @defaultSchema44 = SCHEMA_NAME();
    DECLARE @description44 AS sql_variant;
    SET @description44 = N'Hoạt động theo giờ trong lịch trình (timeline trong ngày)';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet';
    SET @description44 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'Id';
    SET @description44 = N'Lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'LichTrinhId';
    SET @description44 = N'Ngày của hoạt động; NULL = áp dụng cho mọi lần lặp';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'NgayLanLap';
    SET @description44 = N'Giờ bắt đầu';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'GioBatDau';
    SET @description44 = N'Giờ kết thúc';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'GioKetThuc';
    SET @description44 = N'Tên hoạt động, vd Ăn sáng, Tham quan';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'TieuDe';
    SET @description44 = N'Địa điểm';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'DiaDiem';
    SET @description44 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'GhiChu';
    SET @description44 = N'Chi phí dự kiến';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'ChiPhi';
    SET @description44 = N'Đã hoàn thành';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'DaXong';
    SET @description44 = N'Biểu tượng';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'BieuTuong';
    SET @description44 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'ThuTu';
    SET @description44 = N'Người thêm';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'NguoiThemId';
    SET @description44 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'NgayTao';
    SET @description44 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'NgayCapNhat';
    SET @description44 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description44, 'SCHEMA', @defaultSchema44, 'TABLE', N'LichTrinhChiTiet', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070025_LichTrinhChiTiet'
)
BEGIN
    CREATE INDEX [IX_LichTrinhChiTiet_LichTrinhId_NgayLanLap_GioBatDau] ON [LichTrinhChiTiet] ([LichTrinhId], [NgayLanLap], [GioBatDau]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070025_LichTrinhChiTiet'
)
BEGIN
    CREATE INDEX [IX_LichTrinhChiTiet_NgayCapNhat] ON [LichTrinhChiTiet] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070025_LichTrinhChiTiet'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120070025_LichTrinhChiTiet', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070403_DanhMucLichTrinh'
)
BEGIN
    DECLARE @defaultSchema45 AS sysname;
    SET @defaultSchema45 = SCHEMA_NAME();
    DECLARE @description45 AS sql_variant;
    EXEC sp_dropextendedproperty 'MS_Description', 'SCHEMA', @defaultSchema45, 'TABLE', N'LichTrinh', 'COLUMN', N'PhanLoai';
    SET @description45 = N'Loại: 1=đi chơi, 2=công việc, 99=khác (cũ, nay dùng DanhMucId)';
    EXEC sp_addextendedproperty 'MS_Description', @description45, 'SCHEMA', @defaultSchema45, 'TABLE', N'LichTrinh', 'COLUMN', N'PhanLoai';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070403_DanhMucLichTrinh'
)
BEGIN
    ALTER TABLE [LichTrinh] ADD [DanhMucId] uniqueidentifier NULL;
    DECLARE @defaultSchema46 AS sysname;
    SET @defaultSchema46 = SCHEMA_NAME();
    DECLARE @description46 AS sql_variant;
    SET @description46 = N'Danh mục lịch trình do người dùng cấu hình (DanhMuc loại 3)';
    EXEC sp_addextendedproperty 'MS_Description', @description46, 'SCHEMA', @defaultSchema46, 'TABLE', N'LichTrinh', 'COLUMN', N'DanhMucId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070403_DanhMucLichTrinh'
)
BEGIN
    DECLARE @defaultSchema47 AS sysname;
    SET @defaultSchema47 = SCHEMA_NAME();
    DECLARE @description47 AS sql_variant;
    EXEC sp_dropextendedproperty 'MS_Description', 'SCHEMA', @defaultSchema47, 'TABLE', N'DanhMuc', 'COLUMN', N'Loai';
    SET @description47 = N'Loại: 1=chi, 2=thu, 3=lịch trình';
    EXEC sp_addextendedproperty 'MS_Description', @description47, 'SCHEMA', @defaultSchema47, 'TABLE', N'DanhMuc', 'COLUMN', N'Loai';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070403_DanhMucLichTrinh'
)
BEGIN
    CREATE INDEX [IX_LichTrinh_DanhMucId] ON [LichTrinh] ([DanhMucId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120070403_DanhMucLichTrinh'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120070403_DanhMucLichTrinh', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120071506_CauHinhThoiGian'
)
BEGIN
    DECLARE @defaultSchema48 AS sysname;
    SET @defaultSchema48 = SCHEMA_NAME();
    DECLARE @description48 AS sql_variant;
    EXEC sp_dropextendedproperty 'MS_Description', 'SCHEMA', @defaultSchema48, 'TABLE', N'DanhMuc', 'COLUMN', N'Loai';
    SET @description48 = N'Loại: 1=chi, 2=thu, 3=lịch trình, 4=mẫu hoạt động trong ngày';
    EXEC sp_addextendedproperty 'MS_Description', @description48, 'SCHEMA', @defaultSchema48, 'TABLE', N'DanhMuc', 'COLUMN', N'Loai';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120071506_CauHinhThoiGian'
)
BEGIN
    ALTER TABLE [CaiDat] ADD [CauHinhThoiGianJson] nvarchar(max) NULL;
    DECLARE @defaultSchema49 AS sysname;
    SET @defaultSchema49 = SCHEMA_NAME();
    DECLARE @description49 AS sql_variant;
    SET @description49 = N'Cấu hình thời gian (JSON): các mốc nhắc, nhắc mặc định, khung giờ timeline, bước làm tròn, thời lượng hoạt động mặc định';
    EXEC sp_addextendedproperty 'MS_Description', @description49, 'SCHEMA', @defaultSchema49, 'TABLE', N'CaiDat', 'COLUMN', N'CauHinhThoiGianJson';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120071506_CauHinhThoiGian'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120071506_CauHinhThoiGian', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    ALTER TABLE [HoaDonDien] ADD [CongToId] uniqueidentifier NULL;
    DECLARE @defaultSchema50 AS sysname;
    SET @defaultSchema50 = SCHEMA_NAME();
    DECLARE @description50 AS sql_variant;
    SET @description50 = N'Công tơ (NULL = hoá đơn tổng EVN của cả nhà)';
    EXEC sp_addextendedproperty 'MS_Description', @description50, 'SCHEMA', @defaultSchema50, 'TABLE', N'HoaDonDien', 'COLUMN', N'CongToId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    CREATE TABLE [CongTo] (
        [Id] uniqueidentifier NOT NULL,
        [Ten] nvarchar(100) NOT NULL,
        [PhanLoai] tinyint NOT NULL,
        [TenNguoiThue] nvarchar(100) NULL,
        [BangGiaId] uniqueidentifier NOT NULL,
        [ChiSoBanDau] int NOT NULL,
        [DanhMucId] uniqueidentifier NULL,
        [TaiKhoanId] uniqueidentifier NULL,
        [ThuTu] int NOT NULL,
        [DaLuuTru] bit NOT NULL,
        [GhiChu] nvarchar(max) NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_CongTo] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_CongTo_BangGiaDien_BangGiaId] FOREIGN KEY ([BangGiaId]) REFERENCES [BangGiaDien] ([Id]) ON DELETE NO ACTION,
        CONSTRAINT [FK_CongTo_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema51 AS sysname;
    SET @defaultSchema51 = SCHEMA_NAME();
    DECLARE @description51 AS sql_variant;
    SET @description51 = N'Công tơ điện (mỗi tầng/phòng một cái): dùng riêng hoặc cho thuê';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo';
    SET @description51 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'Id';
    SET @description51 = N'Tên công tơ, vd Tầng 3';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'Ten';
    SET @description51 = N'Loại: 1=nhà dùng (khoản chi), 2=cho thuê (khoản thu)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'PhanLoai';
    SET @description51 = N'Tên người thuê (khi cho thuê)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'TenNguoiThue';
    SET @description51 = N'Bảng giá áp dụng cho công tơ này';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'BangGiaId';
    SET @description51 = N'Chỉ số lúc bắt đầu theo dõi';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'ChiSoBanDau';
    SET @description51 = N'Danh mục dùng khi tạo giao dịch (NULL = tự chọn theo loại)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'DanhMucId';
    SET @description51 = N'Tài khoản dùng khi tạo giao dịch (NULL = tài khoản mặc định)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'TaiKhoanId';
    SET @description51 = N'Thứ tự hiển thị';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'ThuTu';
    SET @description51 = N'Đã ngừng theo dõi';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'DaLuuTru';
    SET @description51 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'GhiChu';
    SET @description51 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'NgayTao';
    SET @description51 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'NgayCapNhat';
    SET @description51 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'NgayXoa';
    SET @description51 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description51, 'SCHEMA', @defaultSchema51, 'TABLE', N'CongTo', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    CREATE INDEX [IX_HoaDonDien_CongToId_Ky] ON [HoaDonDien] ([CongToId], [Ky]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    CREATE INDEX [IX_CongTo_BangGiaId] ON [CongTo] ([BangGiaId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    CREATE INDEX [IX_CongTo_NguoiDungId_NgayCapNhat] ON [CongTo] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    CREATE INDEX [IX_CongTo_NguoiDungId_ThuTu] ON [CongTo] ([NguoiDungId], [ThuTu]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    ALTER TABLE [HoaDonDien] ADD CONSTRAINT [FK_HoaDonDien_CongTo_CongToId] FOREIGN KEY ([CongToId]) REFERENCES [CongTo] ([Id]) ON DELETE NO ACTION;
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120075622_CongToDien'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120075622_CongToDien', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120092331_CapDoi'
)
BEGIN
    ALTER TABLE [BanBe] ADD [CapDoiTu] datetimeoffset NULL;
    DECLARE @defaultSchema52 AS sysname;
    SET @defaultSchema52 = SCHEMA_NAME();
    DECLARE @description52 AS sql_variant;
    SET @description52 = N'Thời điểm hai người xác nhận là người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description52, 'SCHEMA', @defaultSchema52, 'TABLE', N'BanBe', 'COLUMN', N'CapDoiTu';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120092331_CapDoi'
)
BEGIN
    ALTER TABLE [BanBe] ADD [NguoiMoiCapDoiId] uniqueidentifier NULL;
    DECLARE @defaultSchema53 AS sysname;
    SET @defaultSchema53 = SCHEMA_NAME();
    DECLARE @description53 AS sql_variant;
    SET @description53 = N'Người gửi lời mời làm người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description53, 'SCHEMA', @defaultSchema53, 'TABLE', N'BanBe', 'COLUMN', N'NguoiMoiCapDoiId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120092331_CapDoi'
)
BEGIN
    ALTER TABLE [BanBe] ADD [TrangThaiCapDoi] tinyint NULL;
    DECLARE @defaultSchema54 AS sysname;
    SET @defaultSchema54 = SCHEMA_NAME();
    DECLARE @description54 AS sql_variant;
    SET @description54 = N'Cặp đôi: NULL=không, 1=đang chờ xác nhận, 2=đã là người yêu';
    EXEC sp_addextendedproperty 'MS_Description', @description54, 'SCHEMA', @defaultSchema54, 'TABLE', N'BanBe', 'COLUMN', N'TrangThaiCapDoi';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120092331_CapDoi'
)
BEGIN
    EXEC(N'CREATE INDEX [IX_BanBe_TrangThaiCapDoi] ON [BanBe] ([TrangThaiCapDoi]) WHERE [TrangThaiCapDoi] IS NOT NULL');
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120092331_CapDoi'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120092331_CapDoi', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    ALTER TABLE [NguoiDung] ADD [DongYDieuKhoanLuc] datetimeoffset NULL;
    DECLARE @defaultSchema55 AS sysname;
    SET @defaultSchema55 = SCHEMA_NAME();
    DECLARE @description55 AS sql_variant;
    SET @description55 = N'Thời điểm đồng ý Điều khoản sử dụng & Chính sách quyền riêng tư';
    EXEC sp_addextendedproperty 'MS_Description', @description55, 'SCHEMA', @defaultSchema55, 'TABLE', N'NguoiDung', 'COLUMN', N'DongYDieuKhoanLuc';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    CREATE TABLE [BaoCaoViPham] (
        [Id] uniqueidentifier NOT NULL,
        [NguoiBaoCaoId] uniqueidentifier NOT NULL,
        [LoaiDoiTuong] tinyint NOT NULL,
        [DoiTuongId] uniqueidentifier NOT NULL,
        [NguoiBiBaoCaoId] uniqueidentifier NULL,
        [LyDo] tinyint NOT NULL,
        [GhiChu] nvarchar(max) NULL,
        [TrangThai] tinyint NOT NULL,
        [XuLyLuc] datetimeoffset NULL,
        [NguoiXuLyId] uniqueidentifier NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        CONSTRAINT [PK_BaoCaoViPham] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_BaoCaoViPham_NguoiDung_NguoiBaoCaoId] FOREIGN KEY ([NguoiBaoCaoId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema56 AS sysname;
    SET @defaultSchema56 = SCHEMA_NAME();
    DECLARE @description56 AS sql_variant;
    SET @description56 = N'Báo cáo nội dung / người dùng vi phạm (yêu cầu của App Store với nội dung do người dùng tạo)';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham';
    SET @description56 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'Id';
    SET @description56 = N'Người gửi báo cáo';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NguoiBaoCaoId';
    SET @description56 = N'Loại đối tượng: 1 bài viết, 2 bình luận, 3 người dùng, 4 tin nhắn';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'LoaiDoiTuong';
    SET @description56 = N'Id đối tượng bị báo cáo';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'DoiTuongId';
    SET @description56 = N'Người bị báo cáo (chủ nội dung)';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NguoiBiBaoCaoId';
    SET @description56 = N'Lý do: 1 spam, 2 quấy rối, 3 tình dục, 4 bạo lực, 5 thù ghét, 6 lừa đảo, 99 khác';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'LyDo';
    SET @description56 = N'Mô tả thêm của người báo cáo';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'GhiChu';
    SET @description56 = N'Trạng thái: 1 chờ xử lý, 2 đã gỡ nội dung, 3 bỏ qua';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'TrangThai';
    SET @description56 = N'Thời điểm xử lý';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'XuLyLuc';
    SET @description56 = N'Quản trị viên xử lý';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NguoiXuLyId';
    SET @description56 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NgayTao';
    SET @description56 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NgayCapNhat';
    SET @description56 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description56, 'SCHEMA', @defaultSchema56, 'TABLE', N'BaoCaoViPham', 'COLUMN', N'NgayXoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    CREATE INDEX [IX_BaoCaoViPham_NgayCapNhat] ON [BaoCaoViPham] ([NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    CREATE INDEX [IX_BaoCaoViPham_NguoiBaoCaoId_LoaiDoiTuong_DoiTuongId] ON [BaoCaoViPham] ([NguoiBaoCaoId], [LoaiDoiTuong], [DoiTuongId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    CREATE INDEX [IX_BaoCaoViPham_TrangThai_NgayTao] ON [BaoCaoViPham] ([TrangThai], [NgayTao]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120103514_KiemDuyetNoiDung'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120103514_KiemDuyetNoiDung', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120115727_AnhHoatDong'
)
BEGIN
    ALTER TABLE [AnhLichTrinh] ADD [HoatDongId] uniqueidentifier NULL;
    DECLARE @defaultSchema57 AS sysname;
    SET @defaultSchema57 = SCHEMA_NAME();
    DECLARE @description57 AS sql_variant;
    SET @description57 = N'Hoạt động trong lịch trình (NULL = ảnh chung của album)';
    EXEC sp_addextendedproperty 'MS_Description', @description57, 'SCHEMA', @defaultSchema57, 'TABLE', N'AnhLichTrinh', 'COLUMN', N'HoatDongId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120115727_AnhHoatDong'
)
BEGIN
    CREATE INDEX [IX_AnhLichTrinh_HoatDongId] ON [AnhLichTrinh] ([HoatDongId]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120115727_AnhHoatDong'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120115727_AnhHoatDong', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120122634_KhoaTaiKhoan'
)
BEGIN
    ALTER TABLE [NguoiDung] ADD [BiKhoa] bit NOT NULL DEFAULT CAST(0 AS bit);
    DECLARE @defaultSchema58 AS sysname;
    SET @defaultSchema58 = SCHEMA_NAME();
    DECLARE @description58 AS sql_variant;
    SET @description58 = N'Tài khoản bị quản trị viên khoá (không đăng nhập được)';
    EXEC sp_addextendedproperty 'MS_Description', @description58, 'SCHEMA', @defaultSchema58, 'TABLE', N'NguoiDung', 'COLUMN', N'BiKhoa';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261120122634_KhoaTaiKhoan'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261120122634_KhoaTaiKhoan', N'10.0.15');
END;

COMMIT;
GO

BEGIN TRANSACTION;
IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261122041306_NhacNho'
)
BEGIN
    CREATE TABLE [NhacNho] (
        [Id] uniqueidentifier NOT NULL,
        [TieuDe] nvarchar(200) NOT NULL,
        [GhiChu] nvarchar(max) NULL,
        [BieuTuong] nvarchar(50) NULL,
        [MauSac] nvarchar(9) NULL,
        [CheDoLap] tinyint NOT NULL,
        [CacGio] nvarchar(200) NOT NULL,
        [CacThu] nvarchar(20) NULL,
        [CacNgay] nvarchar(4000) NULL,
        [DangBat] bit NOT NULL,
        [ThuTu] int NOT NULL,
        [NgayTao] datetimeoffset NOT NULL,
        [NgayCapNhat] datetimeoffset NOT NULL,
        [NgayXoa] datetimeoffset NULL,
        [NguoiDungId] uniqueidentifier NOT NULL,
        CONSTRAINT [PK_NhacNho] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_NhacNho_NguoiDung_NguoiDungId] FOREIGN KEY ([NguoiDungId]) REFERENCES [NguoiDung] ([Id]) ON DELETE NO ACTION
    );
    DECLARE @defaultSchema59 AS sysname;
    SET @defaultSchema59 = SCHEMA_NAME();
    DECLARE @description59 AS sql_variant;
    SET @description59 = N'Nhắc nhở do người dùng tự đặt (uống nước, uống thuốc...)';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho';
    SET @description59 = N'Khoá chính (UUID v7 do app sinh)';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'Id';
    SET @description59 = N'Nội dung nhắc';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'TieuDe';
    SET @description59 = N'Ghi chú';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'GhiChu';
    SET @description59 = N'Tên icon';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'BieuTuong';
    SET @description59 = N'Màu (hex)';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'MauSac';
    SET @description59 = N'Lặp lại: 1=hằng ngày, 2=theo thứ trong tuần, 3=từng ngày cụ thể';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'CheDoLap';
    SET @description59 = N'Các giờ nhắc trong ngày, vd 07:30,21:00';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'CacGio';
    SET @description59 = N'Các thứ nhắc khi lặp theo thứ: 1=Thứ 2 ... 7=Chủ nhật, vd 1,3,5';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'CacThu';
    SET @description59 = N'Các ngày nhắc khi chọn từng ngày, vd 2026-11-25,2026-11-28';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'CacNgay';
    SET @description59 = N'Đang bật';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'DangBat';
    SET @description59 = N'Thứ tự sắp xếp';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'ThuTu';
    SET @description59 = N'Thời điểm tạo (UTC)';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'NgayTao';
    SET @description59 = N'Thời điểm sửa gần nhất (UTC) - dùng để đồng bộ';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'NgayCapNhat';
    SET @description59 = N'Thời điểm xoá mềm (UTC), NULL = chưa xoá';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'NgayXoa';
    SET @description59 = N'Người dùng sở hữu bản ghi';
    EXEC sp_addextendedproperty 'MS_Description', @description59, 'SCHEMA', @defaultSchema59, 'TABLE', N'NhacNho', 'COLUMN', N'NguoiDungId';
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261122041306_NhacNho'
)
BEGIN
    CREATE INDEX [IX_NhacNho_NguoiDungId_NgayCapNhat] ON [NhacNho] ([NguoiDungId], [NgayCapNhat]);
END;

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20261122041306_NhacNho'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20261122041306_NhacNho', N'10.0.15');
END;

COMMIT;
GO

