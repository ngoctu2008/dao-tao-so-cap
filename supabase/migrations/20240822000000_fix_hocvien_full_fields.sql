-- (Previous fixes for fields and recalculation)

CREATE OR REPLACE FUNCTION admin_save_hocvien(
    p_token TEXT,
    p_mode TEXT,
    p_data jsonb
) RETURNS json AS $$
DECLARE
    v_user VARCHAR;
BEGIN
    SELECT Username INTO v_user FROM UserSessions WHERE TokenHash = encode(digest(p_token, 'sha256'), 'hex') AND ExpiresAt > CURRENT_TIMESTAMP;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Token không hợp lệ hoặc đã hết hạn');
    END IF;

    IF p_mode = 'add' THEN
        INSERT INTO HocVien (MaHV, MaKhoa, HoTen, GioiTinh, NgaySinh, NoiCuTru, HKTT, SoCC, NgayCC, NoiCC, DanToc, TonGiao, TrinhDoVH, Dienthoai, MaDoiTuong, TrangThaiDuyet, GhiChu, ViecLamSauDaoTao)
        VALUES (
            p_data->>'MaHV',
            p_data->>'MaKhoa',
            p_data->>'HoTen',
            p_data->>'GioiTinh',
            (p_data->>'NgaySinh')::DATE,
            p_data->>'NoiCuTru',
            p_data->>'HKTT',
            p_data->>'SoCC',
            (p_data->>'NgayCC')::DATE,
            p_data->>'NoiCC',
            p_data->>'DanToc',
            p_data->>'TonGiao',
            p_data->>'TrinhDoVH',
            p_data->>'Dienthoai',
            (p_data->>'MaDoiTuong')::INT,
            p_data->>'TrangThaiDuyet',
            p_data->>'GhiChu',
            p_data->>'ViecLamSauDaoTao'
        );
    ELSIF p_mode = 'edit' THEN
        UPDATE HocVien
        SET
            MaKhoa = COALESCE(p_data->>'MaKhoa', MaKhoa),
            HoTen = COALESCE(p_data->>'HoTen', HoTen),
            GioiTinh = COALESCE(p_data->>'GioiTinh', GioiTinh),
            NgaySinh = COALESCE((p_data->>'NgaySinh')::DATE, NgaySinh),
            NoiCuTru = COALESCE(p_data->>'NoiCuTru', NoiCuTru),
            HKTT = COALESCE(p_data->>'HKTT', HKTT),
            SoCC = COALESCE(p_data->>'SoCC', SoCC),
            NgayCC = COALESCE((p_data->>'NgayCC')::DATE, NgayCC),
            NoiCC = COALESCE(p_data->>'NoiCC', NoiCC),
            DanToc = COALESCE(p_data->>'DanToc', DanToc),
            TonGiao = COALESCE(p_data->>'TonGiao', TonGiao),
            TrinhDoVH = COALESCE(p_data->>'TrinhDoVH', TrinhDoVH),
            Dienthoai = COALESCE(p_data->>'Dienthoai', Dienthoai),
            MaDoiTuong = COALESCE((p_data->>'MaDoiTuong')::INT, MaDoiTuong),
            TrangThaiDuyet = COALESCE(p_data->>'TrangThaiDuyet', TrangThaiDuyet),
            GhiChu = COALESCE(p_data->>'GhiChu', GhiChu),
            ViecLamSauDaoTao = COALESCE(p_data->>'ViecLamSauDaoTao', ViecLamSauDaoTao)
        WHERE MaHV = p_data->>'MaHV';
    END IF;

    RETURN json_build_object('success', true, 'message', 'Lưu thành công');
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object('success', false, 'message', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


CREATE OR REPLACE FUNCTION get_hocvien(
    p_token TEXT,
    p_makhoa TEXT DEFAULT NULL,
    p_ttduyet TEXT DEFAULT NULL
)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
BEGIN
    SELECT Username INTO v_user FROM UserSessions WHERE TokenHash = encode(digest(p_token, 'sha256'), 'hex') AND ExpiresAt > CURRENT_TIMESTAMP;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Token không hợp lệ hoặc đã hết hạn');
    END IF;

    RETURN json_build_object('success', true, 'data', (
        SELECT json_agg(json_build_object(
            'MaHV', h.MaHV,
            'MaKhoa', h.MaKhoa,
            'HoTen', h.HoTen,
            'GioiTinh', h.GioiTinh,
            'NgaySinh', h.NgaySinh,
            'NoiCuTru', h.NoiCuTru,
            'HKTT', h.HKTT,
            'SoCC', h.SoCC,
            'NgayCC', h.NgayCC,
            'NoiCC', h.NoiCC,
            'DanToc', h.DanToc,
            'TonGiao', h.TonGiao,
            'TrinhDoVH', h.TrinhDoVH,
            'Dienthoai', h.Dienthoai,
            'MaDoiTuong', h.MaDoiTuong,
            'TrangThaiDuyet', h.TrangThaiDuyet,
            'GhiChu', h.GhiChu,
            'ViecLamSauDaoTao', h.ViecLamSauDaoTao,
            'KhoaDaThamGia', (
                SELECT json_agg(hk.MaKhoa)
                FROM HocVien hk
                WHERE hk.SoCC = h.SoCC AND hk.MaHV != h.MaHV
            )
        ))
        FROM HocVien h
        WHERE (p_makhoa IS NULL OR h.MaKhoa = p_makhoa)
          AND (p_ttduyet IS NULL OR h.TrangThaiDuyet = p_ttduyet)
    ));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE OR REPLACE FUNCTION admin_update_cauhinh(p_token TEXT, p_data jsonb)
RETURNS json AS $$
DECLARE
    v_user VARCHAR;
    v_key TEXT;
    v_val TEXT;
BEGIN
    SELECT Username INTO v_user FROM UserSessions WHERE TokenHash = encode(digest(p_token, 'sha256'), 'hex') AND ExpiresAt > CURRENT_TIMESTAMP;
    IF NOT FOUND THEN
        RETURN json_build_object('success', false, 'message', 'Token không hợp lệ hoặc đã hết hạn');
    END IF;

    FOR v_key, v_val IN SELECT * FROM jsonb_each_text(p_data)
    LOOP
        INSERT INTO CauHinh (ConfigKey, ConfigValue)
        VALUES (v_key, v_val)
        ON CONFLICT (ConfigKey) DO UPDATE SET ConfigValue = EXCLUDED.ConfigValue;
    END LOOP;

    RETURN json_build_object('success', true, 'message', 'Cập nhật cấu hình thành công');
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
