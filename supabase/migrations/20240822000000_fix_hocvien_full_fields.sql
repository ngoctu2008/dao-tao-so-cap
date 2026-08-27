CREATE TABLE IF NOT EXISTS AuditLog (
    Id SERIAL PRIMARY KEY,
    Username VARCHAR(50),
    Action VARCHAR(100),
    Details TEXT,
    Timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION admin_save_hocvien(
    p_token TEXT,
    p_mode TEXT,
    p_data JSONB
) RETURNS json AS $$
DECLARE
    v_user_role TEXT;
    v_email TEXT;
    v_ma_khoa TEXT;
    v_gv_email TEXT;
    v_username TEXT;
    v_new_sott INT;
    v_new_mahv VARCHAR;
    v_d1 NUMERIC; v_d2 NUMERIC; v_d3 NUMERIC; v_d4 NUMERIC; v_d5 NUMERIC;
    v_somd INT; v_tong NUMERIC; v_count INT; v_liet BOOLEAN;
    v_tk NUMERIC; v_xl VARCHAR;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_user_role FROM Users WHERE Username = v_username;
    v_email := v_username;

    v_ma_khoa := p_data->>'MaKhoa';
    IF v_user_role = 'Giáo viên' THEN
        SELECT GVCN_Email INTO v_gv_email FROM KhoaHoc WHERE MaKhoa = v_ma_khoa;
        IF v_gv_email IS DISTINCT FROM v_email THEN
            RETURN json_build_object('success', false, 'message', 'Chỉ GVCN lớp này mới có quyền thêm/sửa học viên.');
        END IF;
    END IF;

    BEGIN
        IF p_mode = 'add' THEN
            LOCK TABLE Hocvien IN EXCLUSIVE MODE;
            SELECT COALESCE(MAX(CAST(SUBSTRING(MaHV FROM LENGTH(v_ma_khoa) + 2) AS INT)), 0) + 1 INTO v_new_sott FROM Hocvien WHERE MaKhoa = v_ma_khoa;
            v_new_mahv := v_ma_khoa || '-' || LPAD(v_new_sott::TEXT, 2, '0');

            INSERT INTO Hocvien (
                MaHV, MaKhoa, HoTen, GioiTinh, NgaySinh, SoCC, Dienthoai, MaDoiTuong, ViecLamSauDaoTao,
                TrangThaiDuyet, GhiChu,
                NgayCC, NoiCC, DanToc, TonGiao, TrinhDoVH, HKTT, NoiCuTru
            ) VALUES (
                v_new_mahv,
                v_ma_khoa,
                UPPER(p_data->>'HoTen'),
                p_data->>'GioiTinh',
                NULLIF(p_data->>'NgaySinh', '')::DATE,
                p_data->>'SoCC',
                p_data->>'Dienthoai',
                NULLIF(p_data->>'MaDoiTuong', '')::INT,
                p_data->>'ViecLamSauDaoTao',
                COALESCE(p_data->>'TrangThaiDuyet', 'Chờ duyệt'),
                p_data->>'GhiChu',
                NULLIF(p_data->>'NgayCC', '')::DATE,
                p_data->>'NoiCC',
                p_data->>'DanToc',
                p_data->>'TonGiao',
                p_data->>'TrinhDoVH',
                p_data->>'HKTT',
                p_data->>'NoiCuTru'
            );

            IF v_user_role IN ('Ban Giám đốc', 'Giáo vụ') THEN
                INSERT INTO AuditLog (Username, Action, Details)
                VALUES (v_email, 'INSERT', 'Thêm học viên ' || v_new_mahv);
            END IF;

        ELSIF p_mode = 'edit' THEN
            SELECT MaKhoa INTO v_ma_khoa FROM Hocvien WHERE MaHV = p_data->>'MaHV';
            SELECT n.SoMoDun INTO v_somd FROM Nghedaotao n JOIN Khoahoc k ON k.MaNghe = n.MaNghe WHERE k.MaKhoa = v_ma_khoa;

            UPDATE Hocvien SET
                TrangThaiDuyet = CASE WHEN v_user_role IN ('Ban Giám đốc', 'Giáo vụ') THEN COALESCE(p_data->>'TrangThaiDuyet', TrangThaiDuyet) ELSE TrangThaiDuyet END,
                HoTen = COALESCE(UPPER(p_data->>'HoTen'), HoTen),
                GioiTinh = COALESCE(p_data->>'GioiTinh', GioiTinh),
                NgaySinh = COALESCE(NULLIF(p_data->>'NgaySinh', '')::DATE, NgaySinh),
                SoCC = COALESCE(p_data->>'SoCC', SoCC),
                Dienthoai = COALESCE(p_data->>'Dienthoai', Dienthoai),
                MaDoiTuong = CASE WHEN p_data->>'MaDoiTuong' IS NOT NULL THEN CAST(p_data->>'MaDoiTuong' AS INT) ELSE MaDoiTuong END,
                ViecLamSauDaoTao = COALESCE(p_data->>'ViecLamSauDaoTao', ViecLamSauDaoTao),
                GhiChu = COALESCE(p_data->>'GhiChu', GhiChu),
                NgayCC = CASE WHEN p_data ? 'NgayCC' THEN NULLIF(p_data->>'NgayCC', '')::DATE ELSE NgayCC END,
                NoiCC = CASE WHEN p_data ? 'NoiCC' THEN p_data->>'NoiCC' ELSE NoiCC END,
                DanToc = CASE WHEN p_data ? 'DanToc' THEN p_data->>'DanToc' ELSE DanToc END,
                TonGiao = CASE WHEN p_data ? 'TonGiao' THEN p_data->>'TonGiao' ELSE TonGiao END,
                TrinhDoVH = CASE WHEN p_data ? 'TrinhDoVH' THEN p_data->>'TrinhDoVH' ELSE TrinhDoVH END,
                HKTT = CASE WHEN p_data ? 'HKTT' THEN p_data->>'HKTT' ELSE HKTT END,
                NoiCuTru = CASE WHEN p_data ? 'NoiCuTru' THEN p_data->>'NoiCuTru' ELSE NoiCuTru END,
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

            IF v_user_role IN ('Ban Giám đốc', 'Giáo vụ') THEN
                INSERT INTO AuditLog (Username, Action, Details)
                VALUES (v_email, 'UPDATE', 'Sửa học viên ' || (p_data->>'MaHV'));
            END IF;

        ELSE
            RETURN json_build_object('success', false, 'message', 'Invalid mode');
        END IF;

        RETURN json_build_object('success', true);
    EXCEPTION WHEN unique_violation THEN
        RETURN json_build_object('success', false, 'message', 'Số CCCD này đã tồn tại trong khóa học.');
    END;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;


CREATE OR REPLACE FUNCTION get_hocvien(
    p_token TEXT,
    p_makhoa TEXT DEFAULT NULL,
    p_ttduyet TEXT DEFAULT NULL
) RETURNS json AS $$
DECLARE
    v_user_role TEXT;
    v_email TEXT;
    v_res JSONB;
    v_username TEXT;
BEGIN
    v_username := verify_token(p_token);
    IF v_username IS NULL THEN RETURN json_build_object('success', false, 'message', 'Unauthorized'); END IF;
    SELECT Role INTO v_user_role FROM Users WHERE Username = v_username;
    v_email := v_username;

    SELECT jsonb_agg(
        jsonb_build_object(
            'MaHV', h.MaHV,
            'MaKhoa', h.MaKhoa,
            'HoTen', h.HoTen,
            'GioiTinh', h.GioiTinh,
            'NgaySinh', h.NgaySinh,
            'SoCC', h.SoCC,
            'NgayCC', h.NgayCC,
            'NoiCC', h.NoiCC,
            'DanToc', h.DanToc,
            'TonGiao', h.TonGiao,
            'TrinhDoVH', h.TrinhDoVH,
            'HKTT', h.HKTT,
            'NoiCuTru', h.NoiCuTru,
            'Dienthoai', h.Dienthoai,
            'MaDoiTuong', h.MaDoiTuong,
            'ViecLamSauDaoTao', h.ViecLamSauDaoTao,
            'TrangThaiDuyet', h.TrangThaiDuyet,
            'GhiChu', h.GhiChu,
            'DoiTuong', (SELECT jsonb_build_object('TenDoiTuong', dt.TenDoiTuong) FROM DoiTuong dt WHERE dt.MaDoiTuong = h.MaDoiTuong),
            'KhoaDaThamGia', (
                SELECT jsonb_agg(h2.MaKhoa)
                FROM Hocvien h2
                WHERE h2.SoCC = h.SoCC AND h2.MaHV != h.MaHV
            )
        ) ORDER BY h.MaHV DESC
    ) INTO v_res
    FROM Hocvien h
    LEFT JOIN KhoaHoc k ON h.MaKhoa = k.MaKhoa
    WHERE (p_makhoa IS NULL OR h.MaKhoa = p_makhoa)
      AND (p_ttduyet IS NULL OR h.TrangThaiDuyet = p_ttduyet)
      AND (
          v_user_role IN ('Ban Giám đốc', 'Giáo vụ')
          OR (v_user_role = 'Giáo viên' AND k.GVCN_Email = v_email)
      );

    RETURN json_build_object('success', true, 'data', COALESCE(v_res, '[]'::jsonb));
END;
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

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
$$ LANGUAGE plpgsql SECURITY INVOKER SET search_path = public;

GRANT EXECUTE ON FUNCTION admin_update_cauhinh(TEXT, jsonb) TO anon, authenticated;
