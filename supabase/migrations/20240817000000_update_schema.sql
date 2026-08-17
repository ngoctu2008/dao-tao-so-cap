-- Fix 1: SoCC UNIQUE constraint
ALTER TABLE Hocvien DROP CONSTRAINT hocvien_socc_key;
ALTER TABLE Hocvien ADD CONSTRAINT uq_hocvien_makhoa_socc UNIQUE (MaKhoa, SoCC);

-- Fix 2: Password strength and Exception handling in RPCs
-- Replace change_password
CREATE OR REPLACE FUNCTION change_password(p_token TEXT, p_old_pass TEXT, p_new_pass TEXT)
RETURNS json AS $$
DECLARE
    v_user RECORD;
    v_username VARCHAR;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    IF LENGTH(p_new_pass) < 8 THEN
        RETURN json_build_object('success', false, 'message', 'Mật khẩu phải có ít nhất 8 ký tự');
    END IF;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Replace admin_create_user
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

    IF LENGTH(p_password) < 8 THEN
        RETURN json_build_object('success', false, 'message', 'Mật khẩu phải có ít nhất 8 ký tự');
    END IF;

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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Add AuditLog Table
CREATE TABLE IF NOT EXISTS AuditLog (
    Id SERIAL PRIMARY KEY,
    Username VARCHAR(50) REFERENCES Users(Username) ON DELETE SET NULL,
    Action VARCHAR(100) NOT NULL,
    Details TEXT,
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE AuditLog ENABLE ROW LEVEL SECURITY;

-- Add Indexes
CREATE INDEX IF NOT EXISTS idx_hocvien_makhoa ON Hocvien(MaKhoa);
CREATE INDEX IF NOT EXISTS idx_hocvien_ttduyet ON Hocvien(TrangThaiDuyet);
CREATE INDEX IF NOT EXISTS idx_khoahoc_gvcn ON Khoahoc(GVCN_Email);

-- Update get_hocvien to include KhoaDaThamGia & GhiChu
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
               h.GhiChu as "GhiChu",
               (SELECT row_to_json(dt) FROM (SELECT TenDoiTuong as "TenDoiTuong" FROM DoiTuong WHERE MaDoiTuong = h.MaDoiTuong) dt) as "DoiTuong",
               (SELECT json_agg(h2.MaKhoa) FROM Hocvien h2 WHERE h2.SoCC = h.SoCC AND h2.MaHV != h.MaHV) as "KhoaDaThamGia"
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
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update admin_save_hocvien with AuditLog and Error Handling
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
            ViecLamSauDaoTao, TrangThaiDuyet, GhiChu
        ) VALUES (
            v_new_mahv, v_makhoa, p_data->>'HoTen', p_data->>'GioiTinh', CAST(NULLIF(p_data->>'NgaySinh', '') AS DATE),
            p_data->>'SoCC', p_data->>'Dienthoai', CAST(NULLIF(p_data->>'MaDoiTuong', '') AS INT),
            p_data->>'ViecLamSauDaoTao', COALESCE(p_data->>'TrangThaiDuyet', 'Đã duyệt'), p_data->>'GhiChu'
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
            GhiChu = CASE WHEN p_data ? 'GhiChu' THEN p_data->>'GhiChu' ELSE GhiChu END,
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

        INSERT INTO AuditLog (Username, Action, Details)
        VALUES (v_user, 'EDIT_HOCVIEN', 'Sửa thông tin/điểm học viên ' || (p_data->>'MaHV'));

    END IF;
    RETURN json_build_object('success', true);
EXCEPTION
    WHEN unique_violation THEN
        RETURN json_build_object('success', false, 'message', 'Số CCCD này đã được sử dụng trên hệ thống cho khóa học này');
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


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

    INSERT INTO AuditLog (Username, Action, Details)
    VALUES (v_user, 'DELETE_HOCVIEN', 'Xóa học viên ' || p_mahv);

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

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

    INSERT INTO AuditLog (Username, Action, Details)
    VALUES (v_admin, 'TOGGLE_USER', 'Thay đổi trạng thái tài khoản ' || p_username || ' thành ' || (SELECT TrangThai FROM Users WHERE Username = p_username));

    RETURN json_build_object('success', true);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Scheduled cleanup function (to be called via pg_cron or external scheduler)
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
    DELETE FROM UserSessions WHERE ExpiresAt < CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- admin_update_cauhinh
CREATE OR REPLACE FUNCTION admin_update_cauhinh(p_token TEXT, p_data jsonb)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_role VARCHAR;
    v_key VARCHAR;
    v_val TEXT;
BEGIN
    v_user := verify_token(p_token);
    IF v_user IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;

    SELECT Role INTO v_role FROM Users WHERE Username = v_user;
    IF v_role <> 'Ban Giám đốc' THEN RETURN json_build_object('success', false, 'message', 'Forbidden'); END IF;

    FOR v_key, v_val IN SELECT * FROM jsonb_each_text(p_data)
    LOOP
        INSERT INTO CauHinh (ConfigKey, ConfigValue)
        VALUES (v_key, v_val)
        ON CONFLICT (ConfigKey) DO UPDATE SET ConfigValue = EXCLUDED.ConfigValue;
    END LOOP;

    RETURN json_build_object('success', true, 'message', 'Cập nhật cấu hình thành công');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Update Grants
REVOKE ALL ON FUNCTION get_hocvien(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_save_hocvien(TEXT, TEXT, jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_delete_hocvien(TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION change_password(TEXT, TEXT, TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_create_user(TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_toggle_user(TEXT, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION admin_update_cauhinh(TEXT, jsonb) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION get_hocvien(TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_save_hocvien(TEXT, TEXT, jsonb) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_delete_hocvien(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION change_password(TEXT, TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_create_user(TEXT, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_toggle_user(TEXT, VARCHAR) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION admin_update_cauhinh(TEXT, jsonb) TO anon, authenticated;