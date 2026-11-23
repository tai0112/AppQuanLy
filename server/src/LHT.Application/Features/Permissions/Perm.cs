namespace LHT.Application.Features.Permissions;

/// <summary>Mã chức năng dùng trong code. Danh mục gốc được seed vào DB; admin có thể thêm/sửa/gán lại lúc chạy.</summary>
public static class Perm
{
    public const string GiaoDich = "TAI_CHINH.GIAO_DICH";
    public const string TaiKhoan = "TAI_CHINH.TAI_KHOAN";
    public const string ThongKe = "TAI_CHINH.THONG_KE";
    public const string DanhMuc = "TAI_CHINH.DANH_MUC";
    public const string DinhMuc = "TAI_CHINH.DINH_MUC";
    public const string HuTietKiem = "TAI_CHINH.HU_TIET_KIEM";
    public const string TienDien = "TIEN_ICH.TIEN_DIEN";
    public const string NgayYeu = "TIEN_ICH.NGAY_YEU";
    public const string ChuKy = "TIEN_ICH.CHU_KY";
    public const string NhacNho = "TIEN_ICH.NHAC_NHO";
    public const string LichTrinh = "LICH_TRINH.LICH";
    public const string BanBe = "XA_HOI.BAN_BE";
    public const string TinNhan = "XA_HOI.TIN_NHAN";
    public const string BaiViet = "XA_HOI.BAI_VIET";
    public const string QuanTriVaiTro = "QUAN_TRI.VAI_TRO";
    public const string QuanTriNguoiDung = "QUAN_TRI.NGUOI_DUNG";
    public const string QuanTriChucNang = "QUAN_TRI.CHUC_NANG";
    public const string QuanTriBaoCao = "QUAN_TRI.BAO_CAO";
    public const string QuanTriNhatKy = "QUAN_TRI.NHAT_KY";

    public const string RoleAdmin = "ADMIN";
    public const string RoleUser = "USER";
}
