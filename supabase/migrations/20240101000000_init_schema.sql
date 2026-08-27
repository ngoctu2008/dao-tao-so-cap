CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Bảng Users (Người dùng & Phân quyền)
CREATE TABLE Users (
    Username VARCHAR(50) PRIMARY KEY,
    HoTen VARCHAR(100) NOT NULL,
    Role VARCHAR(50) NOT NULL,
    TrangThai VARCHAR(50) DEFAULT 'Hoạt động',
    MatKhauHash TEXT NOT NULL,
    Salt TEXT NOT NULL,
    PhaiDoiMatKhau BOOLEAN DEFAULT TRUE,
    LanDangNhapSai INT DEFAULT 0,
    ThoiGianKhoa TIMESTAMP
);

-- Bảng Session để Custom Auth
CREATE TABLE UserSessions (
    TokenHash TEXT PRIMARY KEY,
    Username VARCHAR(50) REFERENCES Users(Username) ON DELETE CASCADE,
    ExpiresAt TIMESTAMP NOT NULL
);

-- 2. Bảng DoiTuong
CREATE TABLE DoiTuong (
    MaDoiTuong SERIAL PRIMARY KEY,
    TenDoiTuong VARCHAR(150) NOT NULL,
    ChinhSach TEXT,
    GhiChu TEXT
);

-- 3. Bảng Nghedaotao
CREATE TABLE Nghedaotao (
    MaNghe SERIAL PRIMARY KEY,
    TenNghe VARCHAR(200) NOT NULL,
    LoaiHinh VARCHAR(100),
    SoMoDun INT DEFAULT 1,
    ThoiGianDaoTao INT,
    SoGioDaoTao INT
);

-- 4. Bảng Khoahoc
CREATE TABLE Khoahoc (
    MaKhoa VARCHAR(50) PRIMARY KEY,
    TenKhoa VARCHAR(200) NOT NULL,
    MaNghe INT REFERENCES Nghedaotao(MaNghe) ON DELETE SET NULL,
    GVCN_Email VARCHAR(50) REFERENCES Users(Username) ON DELETE SET NULL,
    TrangThai VARCHAR(50) DEFAULT 'Tuyển sinh',
    DiaDiemDaoTao TEXT,
    TuNgay DATE,
    DenNgay DATE
);

-- 5. Bảng Hocvien
CREATE TABLE Hocvien (
    MaHV VARCHAR(50) PRIMARY KEY,
    MaKhoa VARCHAR(50) REFERENCES Khoahoc(MaKhoa) ON DELETE RESTRICT,
    HoTen VARCHAR(100) NOT NULL,
    GioiTinh VARCHAR(10),
    NgaySinh DATE,
    TrangThaiDuyet VARCHAR(50) DEFAULT 'Chờ duyệt',
    GhiChu TEXT,
    SoCC VARCHAR(20) UNIQUE,
    NgayCC DATE,
    NoiCC TEXT,
    TrinhDoVH VARCHAR(50),
    DanToc VARCHAR(50),
    TonGiao VARCHAR(50),
    HKTT TEXT,
    NguyenQuan TEXT,
    NoiCuTru TEXT,
    Dienthoai VARCHAR(20),
    MaDoiTuong INT REFERENCES DoiTuong(MaDoiTuong) ON DELETE SET NULL,
    ViecLamSauDaoTao VARCHAR(100),
    DiemMD1 NUMERIC(4,1) CHECK (DiemMD1 >= 0 AND DiemMD1 <= 10),
    DiemMD2 NUMERIC(4,1) CHECK (DiemMD2 >= 0 AND DiemMD2 <= 10),
    DiemMD3 NUMERIC(4,1) CHECK (DiemMD3 >= 0 AND DiemMD3 <= 10),
    DiemMD4 NUMERIC(4,1) CHECK (DiemMD4 >= 0 AND DiemMD4 <= 10),
    DiemMD5 NUMERIC(4,1) CHECK (DiemMD5 >= 0 AND DiemMD5 <= 10),
    TongKet NUMERIC(4,1),
    XepLoai VARCHAR(50)
);

-- 6. Bảng ThongBao
CREATE TABLE ThongBao (
    MaTB SERIAL PRIMARY KEY,
    NguoiNhan VARCHAR(50) REFERENCES Users(Username) ON DELETE CASCADE,
    NoiDung TEXT NOT NULL,
    MaKhoa VARCHAR(50) REFERENCES Khoahoc(MaKhoa) ON DELETE SET NULL,
    DaDoc BOOLEAN DEFAULT FALSE,
    ThoiGian TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. Bảng CauHinh
CREATE TABLE CauHinh (
    ConfigKey VARCHAR(50) PRIMARY KEY,
    ConfigValue TEXT
);


-- ==========================================
-- ROW LEVEL SECURITY (RLS) - FIX: DENY ALL DIRECT API ACCESS
-- ==========================================
ALTER TABLE Users ENABLE ROW LEVEL SECURITY;
ALTER TABLE UserSessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE DoiTuong ENABLE ROW LEVEL SECURITY;
ALTER TABLE Nghedaotao ENABLE ROW LEVEL SECURITY;
ALTER TABLE Khoahoc ENABLE ROW LEVEL SECURITY;
ALTER TABLE Hocvien ENABLE ROW LEVEL SECURITY;
ALTER TABLE ThongBao ENABLE ROW LEVEL SECURITY;
ALTER TABLE CauHinh ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public Select CauHinh" ON CauHinh FOR SELECT USING (true);


-- ==========================================
-- RPC FUNCTIONS
-- ==========================================

-- Check Token validity internally
CREATE OR REPLACE FUNCTION verify_token(p_token TEXT)
RETURNS VARCHAR AS $$
DECLARE
    v_user VARCHAR;
BEGIN
    SELECT Username INTO v_user FROM UserSessions WHERE TokenHash = encode(digest(p_token, 'sha256'), 'hex') AND ExpiresAt > CURRENT_TIMESTAMP;
    RETURN v_user;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Đổi mật khẩu (Người dùng tự đổi)
CREATE OR REPLACE FUNCTION change_password(p_token TEXT, p_old_pass TEXT, p_new_pass TEXT)
RETURNS json AS $$
DECLARE
    v_user RECORD;
    v_username VARCHAR;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT * INTO v_user FROM Users WHERE Username = v_username;

    -- Verify old password (bcrypt)
    IF v_user.MatKhauHash = crypt(p_old_pass, v_user.MatKhauHash) THEN
        UPDATE Users
        SET MatKhauHash = crypt(p_new_pass, gen_salt('bf')),
            PhaiDoiMatKhau = FALSE
        WHERE Username = v_username;

        -- Revoke all active sessions
        DELETE FROM UserSessions WHERE Username = v_username;

        RETURN json_build_object('success', true, 'message', 'Đổi mật khẩu thành công');
    ELSE
        RETURN json_build_object('success', false, 'message', 'Mật khẩu cũ không chính xác');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Hàm tạo user an toàn (chỉ Admin)
CREATE OR REPLACE FUNCTION admin_create_user(p_token TEXT, p_username VARCHAR, p_hoten VARCHAR, p_role VARCHAR, p_password VARCHAR)
RETURNS json AS $$
DECLARE
    v_admin VARCHAR;
    v_admin_role VARCHAR;
    v_hash TEXT;
BEGIN
    v_admin := verify_token(p_token);
    IF v_admin IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_admin_role FROM Users WHERE Username = v_admin;
    IF v_admin_role <> 'Ban Giám đốc' THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    -- Bcrypt hashing
    v_hash := crypt(p_password, gen_salt('bf'));

    INSERT INTO Users (Username, HoTen, Role, TrangThai, MatKhauHash, Salt, PhaiDoiMatKhau)
    VALUES (p_username, p_hoten, p_role, 'Hoạt động', v_hash, 'deprecated', TRUE);

    RETURN json_build_object('success', true, 'message', 'Tạo tài khoản thành công');
EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', false, 'message', 'Tên đăng nhập đã tồn tại');
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Hàm RPC Đăng nhập bảo mật (V2)
CREATE OR REPLACE FUNCTION login_user_v2(p_username VARCHAR, p_password VARCHAR)
RETURNS json AS $$
DECLARE
    v_user RECORD;
    v_new_token TEXT;
    v_token_hash TEXT;
BEGIN
    SELECT * INTO v_user FROM Users WHERE Username = p_username;

    IF NOT FOUND THEN RETURN json_build_object('success', false, 'message', 'Tài khoản không tồn tại'); END IF;
    IF v_user.TrangThai <> 'Hoạt động' THEN RETURN json_build_object('success', false, 'message', 'Tài khoản đang bị khóa'); END IF;
    IF v_user.ThoiGianKhoa IS NOT NULL AND v_user.ThoiGianKhoa > CURRENT_TIMESTAMP THEN
        RETURN json_build_object('success', false, 'message', 'Tài khoản bị khóa tạm do nhập sai quá nhiều. Thử lại sau 15 phút.');
    END IF;

    IF v_user.MatKhauHash = crypt(p_password, v_user.MatKhauHash) THEN
        UPDATE Users SET LanDangNhapSai = 0, ThoiGianKhoa = NULL WHERE Username = p_username;
        v_new_token := encode(gen_random_bytes(32), 'hex');
        v_token_hash := encode(digest(v_new_token, 'sha256'), 'hex');
        INSERT INTO UserSessions (TokenHash, Username, ExpiresAt) VALUES (v_token_hash, v_user.Username, CURRENT_TIMESTAMP + INTERVAL '1 day');
        RETURN json_build_object('success', true, 'token', v_new_token, 'user', json_build_object('Username', v_user.Username, 'HoTen', v_user.HoTen, 'Role', v_user.Role, 'PhaiDoiMatKhau', v_user.PhaiDoiMatKhau));
    ELSE
        UPDATE Users SET LanDangNhapSai = COALESCE(LanDangNhapSai, 0) + 1, ThoiGianKhoa = CASE WHEN COALESCE(LanDangNhapSai, 0) + 1 >= 5 THEN CURRENT_TIMESTAMP + INTERVAL '15 minutes' ELSE NULL END WHERE Username = p_username;
        RETURN json_build_object('success', false, 'message', 'Sai mật khẩu');
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- ==== SECURE READ RPCS (PASCALCASE ALIASES FOR JSON OUTPUT) ====

-- Admin & GV: Đọc danh sách khóa học
CREATE OR REPLACE FUNCTION get_khoahoc(p_token TEXT)
RETURNS json AS $$
DECLARE
    v_username VARCHAR;
    v_role VARCHAR;
    v_result json;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_username;

    WITH QueryKhoa AS (
        SELECT k.MaKhoa as "MaKhoa", k.TenKhoa as "TenKhoa", k.MaNghe as "MaNghe", k.GVCN_Email as "GVCN_Email",
               k.TrangThai as "TrangThai", k.DiaDiemDaoTao as "DiaDiemDaoTao", k.TuNgay as "TuNgay", k.DenNgay as "DenNgay",
               (SELECT row_to_json(n) FROM (SELECT MaNghe as "MaNghe", TenNghe as "TenNghe", SoMoDun as "SoMoDun" FROM Nghedaotao WHERE MaNghe = k.MaNghe) n) as "Nghedaotao",
               (SELECT COALESCE(json_agg(row_to_json(h)), '[]') FROM (SELECT MaHV as "MaHV", TrangThaiDuyet as "TrangThaiDuyet" FROM Hocvien WHERE MaKhoa = k.MaKhoa) h) as "Hocvien"
        FROM Khoahoc k
        WHERE (v_role <> 'Giáo viên' OR k.GVCN_Email = v_username)
        ORDER BY k.MaKhoa DESC
    )
    SELECT json_agg(row_to_json(t)) INTO v_result FROM QueryKhoa t;

    RETURN json_build_object('success', true, 'data', COALESCE(v_result, '[]'::json));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Admin & GV: Đọc danh sách học viên
CREATE OR REPLACE FUNCTION get_hocvien(p_token TEXT, p_makhoa TEXT DEFAULT NULL, p_ttduyet TEXT DEFAULT NULL)
RETURNS json AS $$
DECLARE
    v_username VARCHAR;
    v_role VARCHAR;
    v_result json;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_username;

    WITH QueryHocVien AS (
        SELECT h.MaHV as "MaHV", h.MaKhoa as "MaKhoa", h.HoTen as "HoTen", h.GioiTinh as "GioiTinh",
               h.NgaySinh as "NgaySinh", h.SoCC as "SoCC", h.Dienthoai as "Dienthoai", h.TrangThaiDuyet as "TrangThaiDuyet",
               h.MaDoiTuong as "MaDoiTuong", h.ViecLamSauDaoTao as "ViecLamSauDaoTao",
               h.DiemMD1 as "DiemMD1", h.DiemMD2 as "DiemMD2", h.DiemMD3 as "DiemMD3", h.DiemMD4 as "DiemMD4",
               h.DiemMD5 as "DiemMD5", h.TongKet as "TongKet", h.XepLoai as "XepLoai",
               (SELECT row_to_json(dt) FROM (SELECT TenDoiTuong as "TenDoiTuong" FROM DoiTuong WHERE MaDoiTuong = h.MaDoiTuong) dt) as "DoiTuong"
        FROM Hocvien h
        WHERE
            (p_makhoa = '' OR p_makhoa IS NULL OR h.MaKhoa = p_makhoa) AND
            (p_ttduyet = '' OR p_ttduyet IS NULL OR h.TrangThaiDuyet = p_ttduyet) AND
            (v_role <> 'Giáo viên' OR EXISTS (SELECT 1 FROM Khoahoc k2 WHERE k2.MaKhoa = h.MaKhoa AND k2.GVCN_Email = v_username))
        ORDER BY h.MaHV ASC
    )
    SELECT json_agg(row_to_json(t)) INTO v_result FROM QueryHocVien t;

    RETURN json_build_object('success', true, 'data', COALESCE(v_result, '[]'::json));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Thống kê Dashboard
CREATE OR REPLACE FUNCTION get_dashboard_stats(p_token TEXT)
RETURNS json AS $$
DECLARE
    v_username VARCHAR;
    c_lop INT; c_hv INT; c_cho INT; c_tn INT;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT COUNT(*) INTO c_lop FROM Khoahoc;
    SELECT COUNT(*) INTO c_hv FROM Hocvien WHERE TrangThaiDuyet = 'Đã duyệt';
    SELECT COUNT(*) INTO c_cho FROM Hocvien WHERE TrangThaiDuyet = 'Chờ duyệt';
    SELECT COUNT(*) INTO c_tn FROM Hocvien WHERE XepLoai IS NOT NULL AND XepLoai <> 'Không đạt';

    RETURN json_build_object('success', true, 'data', json_build_object('cLop', c_lop, 'cHv', c_hv, 'cCho', c_cho, 'cTn', c_tn));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- Đọc Thông báo
CREATE OR REPLACE FUNCTION get_thongbao(p_token TEXT)
RETURNS json AS $$
DECLARE
    v_username VARCHAR;
    v_role VARCHAR;
    v_result json;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_role FROM Users WHERE Username = v_username;

    WITH QueryThongBao AS (
        SELECT MaTB as "MaTB", NoiDung as "NoiDung", DaDoc as "DaDoc", ThoiGian as "ThoiGian"
        FROM ThongBao
        WHERE v_role <> 'Giáo viên' OR NguoiNhan = v_username
        ORDER BY ThoiGian DESC LIMIT 10
    )
    SELECT json_agg(row_to_json(t)) INTO v_result FROM QueryThongBao t;
    RETURN json_build_object('success', true, 'data', COALESCE(v_result, '[]'::json));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- Cache Data cho form
CREATE OR REPLACE FUNCTION get_cache_data(p_token TEXT)
RETURNS json AS $$
DECLARE
    v_username VARCHAR;
    v_nghe json; v_dt json; v_users json;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT COALESCE(json_agg(row_to_json(n)), '[]') INTO v_nghe FROM (SELECT MaNghe as "MaNghe", TenNghe as "TenNghe", SoMoDun as "SoMoDun" FROM Nghedaotao) n;
    SELECT COALESCE(json_agg(row_to_json(d)), '[]') INTO v_dt FROM (SELECT MaDoiTuong as "MaDoiTuong", TenDoiTuong as "TenDoiTuong" FROM DoiTuong) d;
    SELECT COALESCE(json_agg(row_to_json(u)), '[]') INTO v_users FROM (SELECT Username as "Username", HoTen as "HoTen", Role as "Role" FROM Users) u;

    RETURN json_build_object('success', true, 'data', json_build_object('Nghedaotao', v_nghe, 'DoiTuong', v_dt, 'Users', v_users));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- ==== PUBLIC READ/WRITE (Dành cho Form Đăng Ký - Không cần Token) ====

CREATE OR REPLACE FUNCTION public_get_khoatuyensinh()
RETURNS json AS $$
DECLARE
    v_result json;
BEGIN
    WITH QueryPublic AS (
        SELECT MaKhoa as "MaKhoa", TenKhoa as "TenKhoa" FROM Khoahoc WHERE TrangThai = 'Tuyển sinh' ORDER BY MaKhoa DESC
    )
    SELECT COALESCE(json_agg(row_to_json(t)), '[]') INTO v_result FROM QueryPublic t;
    RETURN json_build_object('success', true, 'data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

CREATE OR REPLACE FUNCTION public_get_doituong()
RETURNS json AS $$
DECLARE
    v_result json;
BEGIN
    WITH QueryPublicDt AS (
        SELECT MaDoiTuong as "MaDoiTuong", TenDoiTuong as "TenDoiTuong" FROM DoiTuong ORDER BY MaDoiTuong ASC
    )
    SELECT COALESCE(json_agg(row_to_json(t)), '[]') INTO v_result FROM QueryPublicDt t;
    RETURN json_build_object('success', true, 'data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


CREATE OR REPLACE FUNCTION register_hocvien(p_data jsonb)
RETURNS json AS $$
DECLARE
    v_makhoa VARCHAR;
    v_new_sott INT;
    v_new_mahv VARCHAR;
    v_gvcn VARCHAR;
    v_trangthai VARCHAR;
    v_socc VARCHAR;
BEGIN
    v_makhoa := p_data->>'MaKhoa';
    v_socc := p_data->>'SoCC';

    -- Kiểm tra trạng thái khóa học
    SELECT TrangThai INTO v_trangthai FROM Khoahoc WHERE MaKhoa = v_makhoa;
    IF v_trangthai IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Khóa học không tồn tại');
    END IF;
    IF v_trangthai <> 'Tuyển sinh' THEN
        RETURN json_build_object('success', false, 'message', 'Khóa học đã đóng đăng ký (không còn ở trạng thái Tuyển sinh)');
    END IF;

    -- Kiểm tra trùng SoCC
    IF EXISTS (SELECT 1 FROM Hocvien WHERE SoCC = v_socc AND MaKhoa = v_makhoa) THEN
        RETURN json_build_object('success', false, 'message', 'Số CCCD này đã đăng ký vào khóa học này rồi');
    END IF;

    PERFORM pg_advisory_xact_lock(hashtext(v_makhoa));
    SELECT COALESCE(MAX(CAST(SUBSTRING(MaHV FROM LENGTH(v_makhoa) + 2) AS INT)), 0) + 1 INTO v_new_sott FROM Hocvien WHERE MaKhoa = v_makhoa;
    v_new_mahv := v_makhoa || '-' || LPAD(v_new_sott::TEXT, 2, '0');

    INSERT INTO Hocvien (
        MaHV, MaKhoa, HoTen, GioiTinh, NgaySinh, SoCC, NgayCC, NoiCC,
        DanToc, TonGiao, TrinhDoVH, HKTT, NoiCuTru, Dienthoai, MaDoiTuong,
        ViecLamSauDaoTao, TrangThaiDuyet
    ) VALUES (
        v_new_mahv, v_makhoa, p_data->>'HoTen', p_data->>'GioiTinh', CAST(NULLIF(p_data->>'NgaySinh', '') AS DATE),
        v_socc, CAST(NULLIF(p_data->>'NgayCC', '') AS DATE), p_data->>'NoiCC', p_data->>'DanToc', p_data->>'TonGiao', p_data->>'TrinhDoVH',
        p_data->>'HKTT', p_data->>'NoiCuTru', p_data->>'Dienthoai', CAST(NULLIF(p_data->>'MaDoiTuong', '') AS INT),
        p_data->>'ViecLamSauDaoTao', 'Chờ duyệt'
    );

    SELECT GVCN_Email INTO v_gvcn FROM Khoahoc WHERE MaKhoa = v_makhoa;
    INSERT INTO ThongBao (NguoiNhan, NoiDung, MaKhoa) VALUES (COALESCE(v_gvcn, 'admin'), 'Học viên mới: ' || (p_data->>'HoTen') || ' vừa đăng ký lớp ' || v_makhoa || '. Vui lòng kiểm tra.', v_makhoa);

    RETURN json_build_object('success', true, 'mahv', v_new_mahv);
EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', false, 'message', 'Số CCCD này đã được sử dụng trên hệ thống');
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


-- ==== ADMIN SECURE WRITES ====

CREATE OR REPLACE FUNCTION admin_save_khoahoc(p_token TEXT, p_mode TEXT, p_data jsonb)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_role FROM Users WHERE Username = v_user;
    IF v_role NOT IN ('Ban Giám đốc', 'Giáo vụ') THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    IF p_mode = 'add' THEN
        INSERT INTO Khoahoc (MaKhoa, TenKhoa, MaNghe, GVCN_Email, TrangThai, DiaDiemDaoTao, TuNgay, DenNgay)
        VALUES (p_data->>'MaKhoa', p_data->>'TenKhoa', CAST(p_data->>'MaNghe' AS INT), NULLIF(p_data->>'GVCN_Email',''), p_data->>'TrangThai', p_data->>'DiaDiemDaoTao', CAST(NULLIF(p_data->>'TuNgay','') AS DATE), CAST(NULLIF(p_data->>'DenNgay','') AS DATE));
    ELSE
        UPDATE Khoahoc SET
            TenKhoa = p_data->>'TenKhoa', MaNghe = CAST(p_data->>'MaNghe' AS INT), GVCN_Email = NULLIF(p_data->>'GVCN_Email',''),
            TrangThai = p_data->>'TrangThai', DiaDiemDaoTao = p_data->>'DiaDiemDaoTao', TuNgay = CAST(NULLIF(p_data->>'TuNgay','') AS DATE), DenNgay = CAST(NULLIF(p_data->>'DenNgay','') AS DATE)
        WHERE MaKhoa = p_data->>'MaKhoa';
    END IF;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


CREATE OR REPLACE FUNCTION admin_delete_khoahoc(p_token TEXT, p_makhoa TEXT)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
    v_count INT;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_role FROM Users WHERE Username = v_user;
    IF v_role NOT IN ('Ban Giám đốc', 'Giáo vụ') THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    SELECT COUNT(*) INTO v_count FROM Hocvien WHERE MaKhoa = p_makhoa;
    IF v_count > 0 THEN
        RETURN json_build_object('success', false, 'message', 'Không thể xóa khóa học vì đã có hồ sơ học viên. Bạn chỉ nên chuyển trạng thái thành "Kết thúc khóa học".');
    END IF;

    DELETE FROM Khoahoc WHERE MaKhoa = p_makhoa;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


CREATE OR REPLACE FUNCTION admin_save_hocvien(p_token TEXT, p_mode TEXT, p_data jsonb)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
    v_makhoa VARCHAR;
    v_gvcn VARCHAR;
    v_new_sott INT;
    v_new_mahv VARCHAR;
    -- Server-side grading calculation variables
    v_d1 NUMERIC; v_d2 NUMERIC; v_d3 NUMERIC; v_d4 NUMERIC; v_d5 NUMERIC;
    v_somd INT; v_tong NUMERIC; v_count INT; v_liet BOOLEAN;
    v_tk NUMERIC; v_xl VARCHAR;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_user;

    IF p_mode = 'add' THEN
        v_makhoa := p_data->>'MaKhoa';

        -- RBAC FIX: Handle NULL gracefully with IS DISTINCT FROM
        IF v_role = 'Giáo viên' THEN
            SELECT GVCN_Email INTO v_gvcn FROM Khoahoc WHERE MaKhoa = v_makhoa;
            IF v_gvcn IS DISTINCT FROM v_user THEN
                RETURN json_build_object('success', false, 'message', 'Forbidden: Not your course');
            END IF;
        END IF;

        LOCK TABLE Hocvien IN EXCLUSIVE MODE;
        SELECT COALESCE(MAX(CAST(SUBSTRING(MaHV FROM LENGTH(v_makhoa) + 2) AS INT)), 0) + 1 INTO v_new_sott FROM Hocvien WHERE MaKhoa = v_makhoa;
        v_new_mahv := v_makhoa || '-' || LPAD(v_new_sott::TEXT, 2, '0');

        INSERT INTO Hocvien (
            MaHV, MaKhoa, HoTen, GioiTinh, NgaySinh, SoCC, Dienthoai, MaDoiTuong,
            ViecLamSauDaoTao, TrangThaiDuyet
        ) VALUES (
            v_new_mahv, v_makhoa, p_data->>'HoTen', p_data->>'GioiTinh', CAST(NULLIF(p_data->>'NgaySinh', '') AS DATE),
            p_data->>'SoCC', p_data->>'Dienthoai', CAST(NULLIF(p_data->>'MaDoiTuong', '') AS INT),
            p_data->>'ViecLamSauDaoTao', COALESCE(p_data->>'TrangThaiDuyet', 'Đã duyệt')
        );

    ELSIF p_mode = 'edit' THEN
        SELECT MaKhoa INTO v_makhoa FROM Hocvien WHERE MaHV = p_data->>'MaHV';

        -- RBAC FIX: Handle NULL gracefully
        IF v_role = 'Giáo viên' THEN
            SELECT GVCN_Email INTO v_gvcn FROM Khoahoc WHERE MaKhoa = v_makhoa;
            IF v_gvcn IS DISTINCT FROM v_user THEN
                RETURN json_build_object('success', false, 'message', 'Forbidden: Not your course');
            END IF;
        END IF;

        -- Lấy số mô đun để tính toán an toàn phía Server
        SELECT n.SoMoDun INTO v_somd FROM Nghedaotao n JOIN Khoahoc k ON k.MaNghe = n.MaNghe WHERE k.MaKhoa = v_makhoa;

        -- Cập nhật thông tin lý lịch cơ bản
        -- SEC-05: Chỉ Ban Giám đốc/Giáo vụ mới được quyền duyệt, Giáo viên giữ nguyên trạng thái cũ
        UPDATE Hocvien SET
            HoTen = COALESCE(p_data->>'HoTen', HoTen),
            TrangThaiDuyet = CASE WHEN v_role IN ('Ban Giám đốc', 'Giáo vụ') THEN COALESCE(p_data->>'TrangThaiDuyet', TrangThaiDuyet) ELSE TrangThaiDuyet END,
            GioiTinh = COALESCE(p_data->>'GioiTinh', GioiTinh),
            Dienthoai = COALESCE(p_data->>'Dienthoai', Dienthoai),
            SoCC = COALESCE(p_data->>'SoCC', SoCC),
            MaDoiTuong = CASE WHEN p_data->>'MaDoiTuong' IS NOT NULL THEN CAST(p_data->>'MaDoiTuong' AS INT) ELSE MaDoiTuong END,
            ViecLamSauDaoTao = COALESCE(p_data->>'ViecLamSauDaoTao', ViecLamSauDaoTao),
            DiemMD1 = CASE WHEN p_data ? 'DiemMD1' THEN CAST(p_data->>'DiemMD1' AS NUMERIC) ELSE DiemMD1 END,
            DiemMD2 = CASE WHEN p_data ? 'DiemMD2' THEN CAST(p_data->>'DiemMD2' AS NUMERIC) ELSE DiemMD2 END,
            DiemMD3 = CASE WHEN p_data ? 'DiemMD3' THEN CAST(p_data->>'DiemMD3' AS NUMERIC) ELSE DiemMD3 END,
            DiemMD4 = CASE WHEN p_data ? 'DiemMD4' THEN CAST(p_data->>'DiemMD4' AS NUMERIC) ELSE DiemMD4 END,
            DiemMD5 = CASE WHEN p_data ? 'DiemMD5' THEN CAST(p_data->>'DiemMD5' AS NUMERIC) ELSE DiemMD5 END
        WHERE MaHV = p_data->>'MaHV';

        -- TÍNH TOÁN LẠI ĐIỂM Ở PHÍA SERVER ĐỂ NGĂN CHẶN CLIENT FAKING
        SELECT DiemMD1, DiemMD2, DiemMD3, DiemMD4, DiemMD5 INTO v_d1, v_d2, v_d3, v_d4, v_d5 FROM Hocvien WHERE MaHV = p_data->>'MaHV';
        v_tong := 0; v_count := 0; v_liet := FALSE;

        IF v_somd >= 1 AND v_d1 IS NOT NULL THEN v_tong := v_tong + v_d1; v_count := v_count + 1; IF v_d1 < 5.0 THEN v_liet := TRUE; END IF; END IF;
        IF v_somd >= 2 AND v_d2 IS NOT NULL THEN v_tong := v_tong + v_d2; v_count := v_count + 1; IF v_d2 < 5.0 THEN v_liet := TRUE; END IF; END IF;
        IF v_somd >= 3 AND v_d3 IS NOT NULL THEN v_tong := v_tong + v_d3; v_count := v_count + 1; IF v_d3 < 5.0 THEN v_liet := TRUE; END IF; END IF;
        IF v_somd >= 4 AND v_d4 IS NOT NULL THEN v_tong := v_tong + v_d4; v_count := v_count + 1; IF v_d4 < 5.0 THEN v_liet := TRUE; END IF; END IF;
        IF v_somd >= 5 AND v_d5 IS NOT NULL THEN v_tong := v_tong + v_d5; v_count := v_count + 1; IF v_d5 < 5.0 THEN v_liet := TRUE; END IF; END IF;

        IF v_count = v_somd THEN
            v_tk := ROUND(v_tong / v_somd, 1);
            IF v_liet THEN v_xl := 'Không đạt';
            ELSE
                IF v_tk >= 9.0 THEN v_xl := 'Xuất sắc';
                ELSIF v_tk >= 8.0 THEN v_xl := 'Giỏi';
                ELSIF v_tk >= 7.0 THEN v_xl := 'Khá';
                ELSIF v_tk >= 5.0 THEN v_xl := 'Trung bình';
                ELSE v_xl := 'Không đạt'; END IF;
            END IF;
            UPDATE Hocvien SET TongKet = v_tk, XepLoai = v_xl WHERE MaHV = p_data->>'MaHV';
        ELSE
            UPDATE Hocvien SET TongKet = NULL, XepLoai = NULL WHERE MaHV = p_data->>'MaHV';
        END IF;

    END IF;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


CREATE OR REPLACE FUNCTION admin_delete_hocvien(p_token TEXT, p_mahv TEXT)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_role FROM Users WHERE Username = v_user;
    IF v_role NOT IN ('Ban Giám đốc', 'Giáo vụ') THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    DELETE FROM Hocvien WHERE MaHV = p_mahv;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

CREATE OR REPLACE FUNCTION mark_read(p_token TEXT, p_matb INT)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    -- Secure check: only allow updating own notifications
    UPDATE ThongBao SET DaDoc = true WHERE MaTB = p_matb AND NguoiNhan = v_user;
    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

-- Revoke all execute rights from public default for all functions
REVOKE ALL ON FUNCTION login_user_v2(VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_khoahoc(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_hocvien(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_dashboard_stats(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_thongbao(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_cache_data(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_save_khoahoc(TEXT, TEXT, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_delete_khoahoc(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_save_hocvien(TEXT, TEXT, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_delete_hocvien(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION mark_read(TEXT, INT) FROM PUBLIC;
REVOKE ALL ON FUNCTION change_password(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_create_user(TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC;
-- Only grant to authenticated or anon if required via Supabase postgREST, but since they use anon key, we must grant back to anon.
GRANT EXECUTE ON FUNCTION login_user_v2(VARCHAR, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public_get_khoatuyensinh() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public_get_doituong() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION register_hocvien(jsonb) TO anon, authenticated;

GRANT EXECUTE ON FUNCTION get_khoahoc(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_hocvien(TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_stats(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_thongbao(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_cache_data(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_save_khoahoc(TEXT, TEXT, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_khoahoc(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_save_hocvien(TEXT, TEXT, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_hocvien(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mark_read(TEXT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION change_password(TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_create_user(TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO anon, authenticated;


-- ==========================================
-- INIT DATA & DỮ LIỆU MẪU
-- ==========================================
INSERT INTO CauHinh (ConfigKey, ConfigValue) VALUES
('LogoUrl', 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a1/Logo_BGD%C4%90T.svg/200px-Logo_BGD%C4%90T.svg.png'),
('TenSite', 'Hệ thống Quản lý Đào tạo Nghề'),
('ChanTrang', '© 2024 Trung tâm GDNN-GDTX khu vực Đăk Hà'),
('MauChuDao', '#004085');

-- Khởi tạo tài khoản admin đầu tiên bằng block nặc danh
DO $$
DECLARE
    v_hash TEXT;
BEGIN
    v_hash := crypt('admin123', gen_salt('bf'));
    INSERT INTO Users (Username, HoTen, Role, TrangThai, MatKhauHash, Salt, PhaiDoiMatKhau)
    VALUES ('admin', 'Ban Giám Đốc Trung Tâm', 'Ban Giám đốc', 'Hoạt động', v_hash, 'deprecated', TRUE)
    ON CONFLICT (Username) DO NOTHING;
END $$;

-- ==== QUẢN LÝ NGƯỜI DÙNG (ADMIN ONLY) ====

CREATE OR REPLACE FUNCTION admin_get_users(p_token TEXT)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
    v_result json;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_user;
    IF v_role <> 'Ban Giám đốc' THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    WITH QueryUsers AS (
        SELECT Username as "Username", HoTen as "HoTen", Role as "Role", TrangThai as "TrangThai",
               LanDangNhapSai as "LanDangNhapSai", ThoiGianKhoa as "ThoiGianKhoa"
        FROM Users ORDER BY Role ASC, Username ASC
    )
    SELECT COALESCE(json_agg(row_to_json(t)), '[]') INTO v_result FROM QueryUsers t;

    RETURN json_build_object('success', true, 'data', v_result);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_toggle_user(p_token TEXT, p_username VARCHAR)
RETURNS json AS $$
DECLARE
    v_admin VARCHAR;
    v_role VARCHAR;
BEGIN
    v_admin := verify_token(p_token);
    IF v_admin IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_admin;
    IF v_role <> 'Ban Giám đốc' THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    IF v_admin = p_username THEN RETURN json_build_object('success', false, 'message', 'Không thể tự khóa chính mình'); END IF;

    UPDATE Users SET TrangThai = CASE WHEN TrangThai = 'Hoạt động' THEN 'Bị khóa' ELSE 'Hoạt động' END,
                     LanDangNhapSai = 0, ThoiGianKhoa = NULL
    WHERE Username = p_username;

    -- Revoke sessions if locked
    DELETE FROM UserSessions WHERE Username = p_username AND (SELECT TrangThai FROM Users WHERE Username = p_username) = 'Bị khóa';

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

GRANT EXECUTE ON FUNCTION admin_get_users(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_user(TEXT, VARCHAR) TO anon, authenticated;
