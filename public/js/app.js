

// ---- GLOBAL STATE ----
let currentUser = null;
let currentToken = null;
let cachedNghe = [];
let cachedDoiTuong = [];
let cachedUsers = [];

// ---- UTILS ----
function escapeHTML(str) {
    if(!str) return '';
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

function getUserName(email) {
    const user = cachedUsers.find(u => u.Username === email);
    return user ? escapeHTML(user.HoTen) : escapeHTML(email);
}

// ---- DOM ELEMENTS ----
const loginScreen = document.getElementById('login-screen');
const appWrapper = document.getElementById('app-wrapper');
const navLinks = document.querySelectorAll('.sidebar .nav-link');
const views = document.querySelectorAll('.view-section');

// ---- INITIALIZATION ----
document.addEventListener('DOMContentLoaded', () => {
    const attachEvt = (id, fn) => { const el = document.getElementById(id); if (el) el.addEventListener('click', fn); };
    attachEvt('btnShowDoiMatKhau', (e) => { e.preventDefault(); appDoiMatKhau.showModal(); });
    attachEvt('btnViewTatCaChoDuyet', (e) => {
        e.preventDefault();
        document.querySelector('.sidebar-nav a[data-target="view-hocvien"]').click();
        document.getElementById('filterDuyet_HV').value='Chờ duyệt';
        setTimeout(loadHocVien, 300);
    });
    attachEvt('btnShortcutTaoKhoa', () => appKhoaHoc.showModal());
    attachEvt('btnShortcutThemHV', () => appHocVien.showModal());
    attachEvt('btnShortcutNhapDiem', () => document.querySelector('.sidebar-nav a[data-target="view-diem"]').click());
    attachEvt('btnThemKhoaMoi', () => appKhoaHoc.showModal());
    attachEvt('btnThemHVMoi', () => appHocVien.showModal());
    attachEvt('btnSaveAllDiem', () => saveAllDiem());
    attachEvt('btnTaoTaiKhoan', () => appUsers.showModal());
    attachEvt('btnCauHinh', () => appCauHinh.showModal());

    checkLoginStatus();

    document.getElementById('frmLogin').addEventListener('submit', handleLogin);

    document.getElementById('btnLogout').addEventListener('click', () => {
        sessionStorage.removeItem('user');
        sessionStorage.removeItem('token');
        window.location.reload();
    });

    navLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = e.currentTarget.getAttribute('data-target');
            navLinks.forEach(l => l.classList.remove('active'));
            e.currentTarget.classList.add('active');
            views.forEach(v => v.classList.remove('active'));
            document.getElementById(targetId).classList.add('active');
            document.getElementById('page-title').innerText = e.currentTarget.innerText.trim();
            loadViewData(targetId);
        });
    });

    document.getElementById('frmSaveKhoaHoc').addEventListener('submit', saveKhoaHoc);
    document.getElementById('frmSaveHocVien').addEventListener('submit', saveHocVien);
    document.getElementById('filterKhoaHoc_HV').addEventListener('change', loadHocVien);
    document.getElementById('filterDuyet_HV').addEventListener('change', loadHocVien);
    document.getElementById('filterKhoaHoc_Diem').addEventListener('change', loadBangDiem);
});

// ---- AUTHENTICATION ----
function checkLoginStatus() {
    const userJson = sessionStorage.getItem('user');
    const tokenStr = sessionStorage.getItem('token');

    if (userJson && tokenStr) {
        currentUser = JSON.parse(userJson);
        currentToken = tokenStr;
        loginScreen.style.display = 'none';
        appWrapper.style.display = 'block';
        document.getElementById('currentUser').innerText = escapeHTML(currentUser.HoTen);
        applyRBAC();
        initAppData(); if(currentUser.PhaiDoiMatKhau) { setTimeout(() => appDoiMatKhau.showModal(true), 500); }
    } else {
        loginScreen.style.display = 'flex';
        appWrapper.style.display = 'none';
    }
}

async function handleLogin(e) {
    e.preventDefault();
    const u = document.getElementById('loginUsername').value;
    const p = document.getElementById('loginPassword').value;
    const alertBox = document.getElementById('loginAlert');
    const alertMsg = document.getElementById('loginAlertMsg');
    const btnSubmit = document.getElementById('btnLoginSubmit');

    // Loading state
    btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2" role="status" aria-hidden="true"></span>ĐANG XỬ LÝ...';
    btnSubmit.disabled = true;
    alertBox.classList.add('d-none');

    try {
        const supabaseMod = await import('./supabase-client.js');
        const supabaseClient = supabaseMod.supabase;

        const { data, error } = await supabaseClient.rpc('login_user_v2', { p_username: u, p_password: p });
        if (error) throw error;
        if (data.success) {
            sessionStorage.setItem('user', JSON.stringify(data.user));
            sessionStorage.setItem('token', data.token);
            window.location.reload();
        } else {
            alertMsg.innerText = data.message;
            alertBox.classList.remove('d-none');
        }
    } catch (err) {
        console.error(err);
        alertMsg.innerText = "Lỗi kết nối hoặc cấu hình mạng! Vui lòng kiểm tra console log.";
        alertBox.classList.remove('d-none');
    } finally {
        btnSubmit.innerHTML = 'ĐĂNG NHẬP';
        btnSubmit.disabled = false;
    }
}

function applyRBAC() {
    const isManager = ['Ban Giám đốc', 'Giáo vụ'].includes(currentUser.Role);
    const isBgd = currentUser.Role === 'Ban Giám đốc';
    if(isBgd) document.querySelectorAll('.bgd-only').forEach(el => el.classList.remove('d-none'));
    else document.querySelectorAll('.bgd-only').forEach(el => el.classList.add('d-none'));
    if(isManager) {
        document.querySelectorAll('.admin-only').forEach(el => el.classList.remove('d-none'));
    } else {
        document.querySelectorAll('.admin-only').forEach(el => el.classList.add('d-none'));
    }
}

// ---- APP DATA INIT ----
async function initAppData() {
    await loadCacheData();
    await Promise.all([loadDashboard(), loadThongBao()]);
}

async function loadCacheData() {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_cache_data', { p_token: currentToken });
    if(data && data.success) {
        cachedNghe = data.data.Nghedaotao || [];
        cachedDoiTuong = data.data.DoiTuong || [];
        cachedUsers = data.data.Users || [];
    }
}

function loadViewData(viewId) {
    if(viewId === 'view-dashboard') loadDashboard();
    if(viewId === 'view-khoahoc') loadDsKhoaHoc();
    if(viewId === 'view-hocvien') initHocVienView();
    if(viewId === 'view-diem') initDiemView();
    if(viewId === 'view-danhmuc') loadDanhMuc();
    if(viewId === 'view-users') loadUsers();
}

// ---- DASHBOARD ----
async function loadDashboard() {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_dashboard_stats', { p_token: currentToken });
    if(data && data.success) {
        document.getElementById('stat-lop').innerText = data.data.cLop || 0;
        document.getElementById('stat-hvdanghoc').innerText = data.data.cHv || 0;
        document.getElementById('stat-choduyet').innerText = data.data.cCho || 0;
        document.getElementById('stat-totnghiep').innerText = data.data.cTn || 0;
    }

    // Tải danh sách hồ sơ mới cần duyệt
    const res = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken, p_makhoa: null, p_ttduyet: 'Chờ duyệt' });
    const tbody = document.getElementById('tblDashboardChoduyet');
    if(res.data && res.data.success && res.data.data.length > 0) {
        tbody.innerHTML = '';
        // Chỉ lấy 5 hồ sơ mới nhất (dựa trên mảng trả về)
        const pendingList = res.data.data.slice(0, 5);
        pendingList.forEach(h => {
            tbody.innerHTML += `
                <tr>
                    <td class="ps-4 fw-medium text-dark">${escapeHTML(h.HoTen)}</td>
                    <td>${escapeHTML(h.MaKhoa)}</td>
                    <td><span class="badge status-choduyet px-2 py-1"><i class="fas fa-clock me-1"></i>Chờ duyệt</span></td>
                </tr>
            `;
        });
    } else {
        tbody.innerHTML = '<tr><td colspan="3" class="text-center py-4 text-muted">Không có hồ sơ nào chờ duyệt.</td></tr>';
    }
}

// ---- THÔNG BÁO ----
async function loadThongBao() {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_thongbao', { p_token: currentToken });
    if(!data || !data.success) return;

    const ul = document.getElementById('listThongBao');
    const badge = document.getElementById('tbCount');
    let unread = 0;

    if(data.data.length > 0) {
        ul.innerHTML = '';
        data.data.forEach(tb => {
            if(!tb.DaDoc) unread++;
            const bgClass = tb.DaDoc ? '' : 'bg-light';
            ul.innerHTML += `
                <li><a class="dropdown-item border-bottom ${bgClass}" href="#" onclick="markRead(${tb.MaTB})">
                    <small class="text-primary">${new Date(tb.ThoiGian).toLocaleString('vi-VN')}</small><br>
                    <span class="text-wrap" style="font-size:0.9rem">${escapeHTML(tb.NoiDung)}</span>
                </a></li>
            `;
        });
    }
    badge.innerText = unread;
}
window.markRead = async function(maTb) {
    const supabaseMod = await import('./supabase-client.js');
    await supabaseMod.supabase.rpc('mark_read', { p_token: currentToken, p_matb: maTb });
    loadThongBao();
}

// ---- MODULE: KHÓA HỌC ----
async function loadDsKhoaHoc() {
    const supabaseMod = await import('./supabase-client.js');
    const tbody = document.getElementById('tblKhoaHoc');
    const { data } = await supabaseMod.supabase.rpc('get_khoahoc', { p_token: currentToken });

    if(!data || !data.success) { tbody.innerHTML = '<tr><td colspan="7">Lỗi tải dữ liệu</td></tr>'; return; }

    tbody.innerHTML = '';
    data.data.forEach(k => {
        const tongSo = k.Hocvien ? k.Hocvien.length : 0;
        const choDuyet = k.Hocvien ? k.Hocvien.filter(h => h.TrangThaiDuyet === 'Chờ duyệt').length : 0;
        let badgeClass = 'badge-tuyensinh';
        if(k.TrangThai === 'Đang đào tạo') badgeClass = 'badge-daotao';
        if(k.TrangThai === 'Kết thúc khóa học') badgeClass = 'badge-ketthuc';

        const row = `
            <tr>
                <td class="fw-bold text-primary">${escapeHTML(k.MaKhoa)}</td>
                <td>${escapeHTML(k.TenKhoa)}<br><small class="text-muted">${k.Nghedaotao ? escapeHTML(k.Nghedaotao.TenNghe) : ''}</small></td>
                <td>${getUserName(k.GVCN_Email)}</td>
                <td><span class="badge ${badgeClass}">${escapeHTML(k.TrangThai)}</span></td>
                <td class="text-center fw-bold">${tongSo - choDuyet}</td>
                <td class="text-center text-danger fw-bold">${choDuyet > 0 ? choDuyet : '-'}</td>
                <td>
                    <button class="btn btn-sm px-3 py-2 btn-outline-info action-btn" data-action="xem-hv" data-id="${escapeHTML(k.MaKhoa)}" title="Quản lý Học viên"><i class="fas fa-users"></i></button>
                    <button class="btn btn-sm px-3 py-2 btn-outline-primary action-btn" data-action="qr" data-id="${escapeHTML(k.MaKhoa)}" data-name="${escapeHTML(k.TenKhoa)}" title="Mã QR"><i class="fas fa-qrcode"></i></button>
                    <button class="btn btn-sm px-3 py-2 btn-outline-success admin-only action-btn" data-action="edit-kh" data-id="${escapeHTML(k.MaKhoa)}" title="Sửa"><i class="fas fa-edit"></i></button>
                    <button class="btn btn-sm px-3 py-2 btn-outline-danger admin-only action-btn" data-action="del-kh" data-id="${escapeHTML(k.MaKhoa)}" title="Xóa"><i class="fas fa-trash"></i></button>
                </td>
            </tr>
        `;
        tbody.innerHTML += row;
    });
    applyRBAC();
}

window.showQR = function(maKhoa, tenKhoa) {
    document.getElementById('qrLop').innerText = tenKhoa;
    const qrContainer = document.getElementById('qrcode');
    qrContainer.innerHTML = '';
    const basePath = window.location.href.substring(0, window.location.href.lastIndexOf('/'));
    new QRCode(qrContainer, { text: `${basePath}/DangKy.html?makhoa=${encodeURIComponent(maKhoa)}`, width: 150, height: 150 });
    new bootstrap.Modal(document.getElementById('modalQR')).show();
}

window.xemHocVienKhoa = function(maKhoa) {
    document.querySelector('.nav-link[data-target="view-hocvien"]').click();
    setTimeout(() => {
        const filter = document.getElementById('filterKhoaHoc_HV');
        if(filter) { filter.value = maKhoa; loadHocVien(); }
    }, 300);
}

window.appKhoaHoc = {
    showModal: function() {
        document.getElementById('frmSaveKhoaHoc').reset();
        document.getElementById('kh_mode').value = 'add';
        document.getElementById('kh_MaKhoa').readOnly = false;
        document.getElementById('kh_MaNghe').innerHTML = cachedNghe.map(n => `<option value="${n.MaNghe}">${escapeHTML(n.TenNghe)}</option>`).join('');
        const gvList = cachedUsers.filter(u => u.Role === 'Giáo viên');
        document.getElementById('kh_GVCN').innerHTML = '<option value="">-- Chọn --</option>' + gvList.map(u => `<option value="${escapeHTML(u.Username)}">${escapeHTML(u.HoTen)}</option>`).join('');
        new bootstrap.Modal(document.getElementById('modalKhoaHoc')).show();
    }
};

window.editKhoaHoc = async function(maKhoa) {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_khoahoc', { p_token: currentToken });
    const kh = data.data.find(k => k.MaKhoa === maKhoa);
    if(kh) {
        appKhoaHoc.showModal();
        document.getElementById('kh_mode').value = 'edit';
        document.getElementById('kh_MaKhoa').value = kh.MaKhoa;
        document.getElementById('kh_MaKhoa').readOnly = true;
        document.getElementById('kh_TenKhoa').value = kh.TenKhoa;
        document.getElementById('kh_MaNghe').value = kh.MaNghe;
        document.getElementById('kh_GVCN').value = kh.GVCN_Email || '';
        document.getElementById('kh_TrangThai').value = kh.TrangThai;
        document.getElementById('kh_DiaDiem').value = kh.DiaDiemDaoTao || '';
        document.getElementById('kh_TuNgay').value = kh.TuNgay || '';
        document.getElementById('kh_DenNgay').value = kh.DenNgay || '';
    }
}

window.deleteKhoaHoc = async function(maKhoa) {
    if(confirm('Chắc chắn xóa khóa học này và tất cả học viên thuộc khóa?')) {
        const supabaseMod = await import('./supabase-client.js');
        const { data } = await supabaseMod.supabase.rpc('admin_delete_khoahoc', { p_token: currentToken, p_makhoa: maKhoa });
        if(!data.success) alert("Lỗi xóa: " + data.message); else { loadDsKhoaHoc(); loadDashboard(); }
    }
}

async function saveKhoaHoc(e) {
    e.preventDefault();
    const dataObj = {
        MaKhoa: document.getElementById('kh_MaKhoa').value,
        TenKhoa: document.getElementById('kh_TenKhoa').value,
        MaNghe: document.getElementById('kh_MaNghe').value,
        GVCN_Email: document.getElementById('kh_GVCN').value || null,
        TrangThai: document.getElementById('kh_TrangThai').value,
        DiaDiemDaoTao: document.getElementById('kh_DiaDiem').value,
        TuNgay: document.getElementById('kh_TuNgay').value || null,
        DenNgay: document.getElementById('kh_DenNgay').value || null
    };
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('admin_save_khoahoc', { p_token: currentToken, p_mode: document.getElementById('kh_mode').value, p_data: dataObj });
    if(!data.success) alert("Lỗi: " + data.message);
    else { bootstrap.Modal.getInstance(document.getElementById('modalKhoaHoc')).hide(); loadDsKhoaHoc(); loadDashboard(); }
}

// ---- MODULE: HỌC VIÊN ----
async function initHocVienView() {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_khoahoc', { p_token: currentToken });
    const filter = document.getElementById('filterKhoaHoc_HV');
    filter.innerHTML = '<option value="">-- Tất cả các khóa --</option>';
    if(data && data.success) {
        data.data.forEach(k => { filter.innerHTML += `<option value="${escapeHTML(k.MaKhoa)}">${escapeHTML(k.MaKhoa)} - ${escapeHTML(k.TenKhoa)}</option>`; });
    }
    loadHocVien();
}

async function loadHocVien() {
    const maKhoa = document.getElementById('filterKhoaHoc_HV').value;
    const ttDuyet = document.getElementById('filterDuyet_HV').value;
    const search = document.getElementById('search_HV')?.value.toLowerCase().trim() || '';
    const tbody = document.getElementById('tblHocVien');

    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken, p_makhoa: maKhoa, p_ttduyet: ttDuyet });
    if(!data || !data.success) { tbody.innerHTML = '<tr><td colspan="5" class="text-center py-4 text-danger">Lỗi tải dữ liệu</td></tr>'; return; }

    let hocviens = data.data;
    if(search) {
        hocviens = hocviens.filter(h =>
            (h.MaHV && h.MaHV.toLowerCase().includes(search)) ||
            (h.HoTen && h.HoTen.toLowerCase().includes(search)) ||
            (h.SoCC && h.SoCC.toLowerCase().includes(search))
        );
    }

    if(hocviens.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" class="text-center py-5 text-muted">Không tìm thấy hồ sơ phù hợp.</td></tr>';
        return;
    }

    tbody.innerHTML = '';
    hocviens.forEach(h => {
        let badgeStatus = '';
        if(h.TrangThaiDuyet === 'Chờ duyệt') badgeStatus = '<span class="badge status-choduyet"><i class="fas fa-clock me-1"></i>Chờ duyệt</span>';
        else if(h.TrangThaiDuyet === 'Đã duyệt') badgeStatus = '<span class="badge status-daduyet"><i class="fas fa-check-circle me-1"></i>Đã duyệt</span>';
        else badgeStatus = `<span class="badge bg-secondary">${escapeHTML(h.TrangThaiDuyet)}</span>`;

        let dienThoai = h.Dienthoai ? h.Dienthoai.replace(/(\d{3})(\d{3})(\d{4})/, '$1 $2 ***') : 'Chưa có SĐT';

        tbody.innerHTML += `
            <tr>
                <td class="ps-4">
                    <span class="fw-bold text-primary">${escapeHTML(h.MaHV)}</span>
                </td>
                <td>
                    <div class="fw-bold text-dark mb-1">${escapeHTML(h.HoTen)}</div>
                    <div class="text-muted small">
                        <i class="fas fa-id-card me-1"></i>${escapeHTML(h.SoCC || '---')} &bull;
                        <i class="fas fa-phone me-1 ms-1"></i>${escapeHTML(dienThoai)}
                    </div>
                </td>
                <td>
                    <div class="mb-1"><span class="badge bg-light text-dark border"><i class="fas fa-layer-group text-muted me-1"></i>${escapeHTML(h.MaKhoa)}</span></div>
                    <div class="text-muted small"><i class="fas fa-tag me-1"></i>${h.DoiTuong ? escapeHTML(h.DoiTuong.TenDoiTuong) : 'Không thuộc ĐTƯT'}</div>
                </td>
                <td>${badgeStatus}</td>
                <td class="text-end pe-4">
                    <div class="btn-group shadow-sm">
                        <button class="btn btn-sm px-3 py-2 btn-light border action-btn text-primary" data-action="view-hv-detail" data-id="${escapeHTML(h.MaHV)}" title="Xem chi tiết"><i class="fas fa-eye"></i></button>
                        <button class="btn btn-sm px-3 py-2 btn-light border action-btn text-success admin-only" data-action="edit-hv" data-id="${escapeHTML(h.MaHV)}" title="Sửa"><i class="fas fa-edit"></i></button>
                        <button class="btn btn-sm px-3 py-2 btn-light border action-btn text-danger admin-only" data-action="del-hv" data-id="${escapeHTML(h.MaHV)}" title="Xóa"><i class="fas fa-trash"></i></button>
                    </div>
                </td>
            </tr>
        `;
    });
    applyRBAC();
}

window.appHocVien = {
    showModal: async function() {
        document.getElementById('frmSaveHocVien').reset();
        document.getElementById('hv_mode').value = 'add'; document.getElementById('hv_MaKhoa').disabled = false;
        const supabaseMod = await import('./supabase-client.js');
        const { data } = await supabaseMod.supabase.rpc('get_khoahoc', { p_token: currentToken });
        document.getElementById('hv_MaKhoa').innerHTML = data.data.map(k => `<option value="${escapeHTML(k.MaKhoa)}">${escapeHTML(k.MaKhoa)}</option>`).join('');
        document.getElementById('hv_MaDoiTuong').innerHTML = '<option value="">Không</option>' + cachedDoiTuong.map(d => `<option value="${d.MaDoiTuong}">${escapeHTML(d.TenDoiTuong)}</option>`).join('');
        new bootstrap.Modal(document.getElementById('modalHocVien')).show();
    }
};

window.editHocVien = async function(maHv) {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken });
    const hv = data.data.find(h => h.MaHV === maHv);
    if(hv) {
        await appHocVien.showModal();
        document.getElementById('hv_mode').value = 'edit';
        document.getElementById('hv_MaHV').value = hv.MaHV;
        document.getElementById('hv_MaKhoa').value = hv.MaKhoa; document.getElementById('hv_MaKhoa').disabled = true;
        document.getElementById('hv_TrangThaiDuyet').value = hv.TrangThaiDuyet;
        document.getElementById('hv_HoTen').value = hv.HoTen;
        document.getElementById('hv_GioiTinh').value = hv.GioiTinh || 'Nam';
        document.getElementById('hv_Dienthoai').value = hv.Dienthoai || '';
        document.getElementById('hv_NgaySinh').value = hv.NgaySinh || '';
        document.getElementById('hv_SoCC').value = hv.SoCC || '';
        document.getElementById('hv_MaDoiTuong').value = hv.MaDoiTuong || '';
        document.getElementById('hv_ViecLam').value = hv.ViecLamSauDaoTao || '';
    }
}

async function saveHocVien(e) {
    e.preventDefault();
    const dataObj = {
        MaHV: document.getElementById('hv_MaHV').value,
        MaKhoa: document.getElementById('hv_MaKhoa').value,
        TrangThaiDuyet: document.getElementById('hv_TrangThaiDuyet').value,
        HoTen: document.getElementById('hv_HoTen').value.toUpperCase(),
        GioiTinh: document.getElementById('hv_GioiTinh').value,
        Dienthoai: document.getElementById('hv_Dienthoai').value,
        NgaySinh: document.getElementById('hv_NgaySinh').value || null,
        SoCC: document.getElementById('hv_SoCC').value,
        MaDoiTuong: document.getElementById('hv_MaDoiTuong').value ? parseInt(document.getElementById('hv_MaDoiTuong').value) : null,
        ViecLamSauDaoTao: document.getElementById('hv_ViecLam').value
    };
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('admin_save_hocvien', { p_token: currentToken, p_mode: document.getElementById('hv_mode').value, p_data: dataObj });
    if(!data.success) alert("Lỗi: " + data.message); else { bootstrap.Modal.getInstance(document.getElementById('modalHocVien')).hide(); loadHocVien(); loadDashboard(); }
}

window.duyetHocVien = async function(maHv) {
    const supabaseMod = await import('./supabase-client.js');

    // Fetch user detail first to check KhoaDaThamGia
    const { data: fetchResult } = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken });
    let isReturning = false;
    if(fetchResult && fetchResult.success && fetchResult.data) {
        const hv = fetchResult.data.find(h => h.MaHV === maHv);
        if(hv && hv.KhoaDaThamGia && hv.KhoaDaThamGia.length > 0) {
            isReturning = true;
        }
    }

    if (isReturning) {
        const reason = prompt('Học viên này đã từng tham gia học trước đây.\nVui lòng nhập nguyên nhân xin học lại (Bắt buộc):');
        if (reason === null) return; // User cancelled
        if (reason.trim() === '') {
            alert('Bạn phải nhập nguyên nhân học lại để duyệt học viên này.');
            return;
        }

        if(confirm('Chấp nhận học viên này vào lớp chính thức?')) {
            const { error } = await supabaseMod.supabase.rpc('admin_save_hocvien', {
                p_token: currentToken,
                p_mode: 'edit',
                p_data: { MaHV: maHv, TrangThaiDuyet: 'Đã duyệt', GhiChu: `[Học lại - Lý do: ${reason}]` }
            });
            if (error) { alert('Lỗi: ' + error.message); }
            loadHocVien(); loadDashboard();
        }
    } else {
        if(confirm('Chấp nhận học viên này vào lớp chính thức?')) {
            await supabaseMod.supabase.rpc('admin_save_hocvien', { p_token: currentToken, p_mode: 'edit', p_data: { MaHV: maHv, TrangThaiDuyet: 'Đã duyệt' } });
            loadHocVien(); loadDashboard();
        }
    }
}

window.xoaHocVien = async function(maHv) {
    if(confirm('CẢNH BÁO: Xóa học viên này?')) {
        const supabaseMod = await import('./supabase-client.js');
        await supabaseMod.supabase.rpc('admin_delete_hocvien', { p_token: currentToken, p_mahv: maHv });
        loadHocVien(); loadDashboard();
    }
}

// ---- MODULE: CHẤM ĐIỂM ----
async function initDiemView() {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_khoahoc', { p_token: currentToken });
    const filter = document.getElementById('filterKhoaHoc_Diem');
    filter.innerHTML = '<option value="">-- Chọn Khóa Học --</option>';
    if(data && data.success) {
        data.data.forEach(k => {
            const soMd = k.Nghedaotao ? k.Nghedaotao.SoMoDun : 1;
            filter.innerHTML += `<option value="${escapeHTML(k.MaKhoa)}" data-somd="${soMd}">${escapeHTML(k.MaKhoa)} - ${escapeHTML(k.TenKhoa)}</option>`;
        });
    }
}

async function loadBangDiem() {
    const filter = document.getElementById('filterKhoaHoc_Diem');
    const maKhoa = filter.value;
    const container = document.getElementById('diemContainer');
    const actions = document.getElementById('diemActions');

    if(!maKhoa) {
        actions.classList.add('d-none');
        container.innerHTML = '<div class="text-center py-5"><div class="bg-secondary bg-opacity-10 rounded-circle d-inline-flex align-items-center justify-content-center mb-3" style="width: 80px; height: 80px;"><i class="fas fa-table fa-2x text-muted"></i></div><h6 class="fw-bold text-dark">Chưa chọn lớp học</h6><p class="text-muted small">Vui lòng chọn một khóa học ở menu trên để bắt đầu nhập điểm</p></div>';
        return;
    }

    const soMd = parseInt(filter.options[filter.selectedIndex].getAttribute('data-somd')) || 5;
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken, p_makhoa: maKhoa, p_ttduyet: 'Đã duyệt' });

    if(!data || !data.success) return;
    const hocviens = data.data;

    if(hocviens.length === 0) {
        actions.classList.add('d-none');
        container.innerHTML = '<div class="text-center py-5"><p class="text-muted">Không có học viên nào đủ điều kiện nhập điểm (Chỉ hiển thị hồ sơ đã được duyệt).</p></div>';
        return;
    }

    actions.classList.remove('d-none');
    document.getElementById('diemStatus').innerHTML = '<i class="fas fa-info-circle me-1"></i>Sẵn sàng';
    document.getElementById('diemStatus').className = 'text-muted small me-3';

    let mdHeaders = '';
    for(let i=1; i<=soMd; i++) mdHeaders += `<th style="width: 90px; text-align:center;">MĐ ${i}</th>`;

    let html = `
        <table class="table table-bordered table-hover align-middle mb-0 table-sticky-header">
            <thead class="table-light">
                <tr>
                    <th style="width: 120px;">Mã HV</th>
                    <th style="min-width: 200px;">Họ Tên</th>
                    ${mdHeaders}
                    <th style="width: 100px; text-align:center;">Tổng Kết</th>
                    <th style="width: 120px; text-align:center;">Xếp Loại</th>
                </tr>
            </thead>
            <tbody>
    `;

    window.currentDiemData = {}; // Store states

    hocviens.forEach(h => {
        let mdInputs = '';
        for(let i=1; i<=soMd; i++) {
            const val = h[`DiemMD${i}`] !== null ? h[`DiemMD${i}`] : '';
            mdInputs += `<td><input type="number" class="form-control text-center diem-input" data-hv="${escapeHTML(h.MaHV)}" data-md="${i}" step="0.1" min="0" max="10" value="${val}"></td>`;
        }
        let rowClass = h.XepLoai === 'Không đạt' ? 'table-danger' : '';
        html += `
            <tr id="row_${escapeHTML(h.MaHV)}" class="${rowClass}">
                <td class="fw-medium text-primary">${escapeHTML(h.MaHV)}</td>
                <td class="fw-bold">${escapeHTML(h.HoTen)}</td>
                ${mdInputs}
                <td><input type="text" class="form-control text-center fw-bold bg-light" id="tk_${escapeHTML(h.MaHV)}" value="${h.TongKet !== null ? h.TongKet : ''}" readonly tabindex="-1"></td>
                <td class="text-center"><span class="badge ${h.XepLoai==='Không đạt'?'status-error':'status-daduyet'}" id="xl_${escapeHTML(h.MaHV)}">${escapeHTML(h.XepLoai || '')}</span></td>
            </tr>
        `;
    });
    html += '</tbody></table>';
    container.innerHTML = html;
    container.className = "p-0"; // remove padding for full width table

    // Attach events for local validation and dirty state
    document.querySelectorAll('.diem-input').forEach(input => {
        input.addEventListener('input', function() {
            const v = parseFloat(this.value);
            if(this.value !== '' && (v < 0 || v > 10)) {
                this.classList.add('is-invalid');
            } else {
                this.classList.remove('is-invalid');
                document.getElementById('diemStatus').innerHTML = '<i class="fas fa-exclamation-circle me-1"></i>Có thay đổi chưa lưu';
                document.getElementById('diemStatus').className = 'text-warning small me-3 fw-bold';
            }
        });
    });
}



// ---- DANH MỤC HỆ THỐNG ----
function loadDanhMuc() {
    const tbNghe = document.getElementById('tblNgheDaoTao');
    tbNghe.innerHTML = '';
    cachedNghe.forEach(n => { tbNghe.innerHTML += `<tr><td>${n.MaNghe}</td><td>${escapeHTML(n.TenNghe)}</td><td>${n.SoMoDun}</td></tr>`; });

    const tbDt = document.getElementById('tblDoiTuong');
    tbDt.innerHTML = '';
    cachedDoiTuong.forEach(d => { tbDt.innerHTML += `<tr><td>${d.MaDoiTuong}</td><td>${escapeHTML(d.TenDoiTuong)}</td></tr>`; });
}

// ---- ĐỔI MẬT KHẨU ----
window.appDoiMatKhau = {
    showModal: function(isForce = false) {
        document.getElementById('frmDoiMatKhau').reset();
        document.getElementById('dmk-alert').style.display = isForce ? 'block' : 'none';

        const modalEl = document.getElementById('modalDoiMatKhau');
        const modal = bootstrap.Modal.getInstance(modalEl) || new bootstrap.Modal(modalEl, {
            backdrop: isForce ? 'static' : true,
            keyboard: !isForce
        });

        if(isForce) {
            modalEl.querySelector('.btn-close').style.display = 'none';
        } else {
            modalEl.querySelector('.btn-close').style.display = 'block';
        }

        modal.show();
    }
};

document.getElementById('frmDoiMatKhau').addEventListener('submit', async (e) => {
    e.preventDefault();
    const oldPass = document.getElementById('dmk_old').value;
    const newPass = document.getElementById('dmk_new').value;
    const confirmPass = document.getElementById('dmk_confirm').value;

    if(newPass !== confirmPass) {
        alert("Mật khẩu xác nhận không khớp!");
        return;
    }

    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('change_password', {
        p_token: currentToken,
        p_old_pass: oldPass,
        p_new_pass: newPass
    });

    if(!data.success) {
        alert("Lỗi: " + data.message);
    } else {
        alert("Đổi mật khẩu thành công! Vui lòng đăng nhập lại.");
        document.getElementById('btnLogout').click();
    }
});

// ---- QUẢN LÝ TÀI KHOẢN ----
async function loadUsers() {
    const tbody = document.getElementById('tblUsers');
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('admin_get_users', { p_token: currentToken });

    if(!data || !data.success) { tbody.innerHTML = '<tr><td colspan="6">Lỗi tải dữ liệu</td></tr>'; return; }

    tbody.innerHTML = '';
    data.data.forEach(u => {
        let badgeStatus = u.TrangThai === 'Hoạt động' ? 'status-daduyet' : 'status-error';

        let bruteHtml = '';
        if(u.LanDangNhapSai > 0) {
            bruteHtml = `<span class="badge bg-warning text-dark">${u.LanDangNhapSai} lần sai</span>`;
            if(u.ThoiGianKhoa && new Date(u.ThoiGianKhoa) > new Date()) {
                bruteHtml += `<br><small class="text-danger">Khóa đến ${new Date(u.ThoiGianKhoa).toLocaleTimeString('vi-VN')}</small>`;
            }
        } else {
            bruteHtml = `<span class="badge bg-light text-muted">Bình thường</span>`;
        }

        const btnToggle = `<button class="btn btn-sm px-3 py-2 btn-outline-${u.TrangThai === 'Hoạt động' ? 'danger' : 'success'} action-btn" data-action="toggle-user" data-id="${escapeHTML(u.Username)}" title="${u.TrangThai === 'Hoạt động' ? 'Khóa' : 'Mở khóa'}"><i class="fas fa-${u.TrangThai === 'Hoạt động' ? 'lock' : 'unlock'}"></i></button>`;

        tbody.innerHTML += `
            <tr>
                <td class="fw-bold">${escapeHTML(u.Username)}</td>
                <td>${escapeHTML(u.HoTen)}</td>
                <td>${escapeHTML(u.Role)}</td>
                <td><span class="badge ${badgeStatus}">${escapeHTML(u.TrangThai)}</span></td>
                <td>${bruteHtml}</td>
                <td>
                    ${btnToggle}
                </td>
            </tr>
        `;
    });
}

window.appUsers = {
    showModal: function() {
        document.getElementById('frmAddUser').reset();
        new bootstrap.Modal(document.getElementById('modalAddUser')).show();
    }
};

document.getElementById('frmAddUser').addEventListener('submit', async (e) => {
    e.preventDefault();
    const u = document.getElementById('u_username').value;
    const h = document.getElementById('u_hoten').value;
    const r = document.getElementById('u_role').value;
    const p = document.getElementById('u_pass').value;

    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('admin_create_user', {
        p_token: currentToken,
        p_username: u,
        p_hoten: h,
        p_role: r,
        p_password: p
    });

    if(!data.success) {
        alert("Lỗi: " + data.message);
    } else {
        bootstrap.Modal.getInstance(document.getElementById('modalAddUser')).hide();
        loadUsers();
    }
});

window.toggleUser = async function(username) {
    if(confirm(`Bạn có chắc muốn thay đổi trạng thái tài khoản ${username}?`)) {
        const supabaseMod = await import('./supabase-client.js');
        const { data } = await supabaseMod.supabase.rpc('admin_toggle_user', { p_token: currentToken, p_username: username });
        if(!data.success) alert("Lỗi: " + data.message);
        else loadUsers();
    }
}

// Global Event Delegation cho các nút thao tác động (Tránh XSS qua inline onclick)
document.addEventListener('click', function(e) {
    const btn = e.target.closest('.action-btn');
    if(!btn) return;

    e.preventDefault();
    const action = btn.getAttribute('data-action');
    const id = btn.getAttribute('data-id');
    const name = btn.getAttribute('data-name');

    if(action === 'xem-hv') window.xemHocVienKhoa(id);
    if(action === 'qr') window.showQR(id, name);
    if(action === 'edit-kh') window.editKhoaHoc(id);
    if(action === 'del-kh') window.deleteKhoaHoc(id);

    if(action === 'view-hv-detail') window.xemHocVienDetail(id);
    if(action === 'duyet-hv') window.duyetHocVien(id);
    if(action === 'edit-hv') window.editHocVien(id);
    if(action === 'del-hv') window.xoaHocVien(id);

    if(action === 'toggle-user') window.toggleUser(id);
});

// ---- TOGGLE PASSWORD VISIBILITY ----
document.getElementById('btnTogglePass')?.addEventListener('click', function() {
    const passInput = document.getElementById('loginPassword');
    const icon = this.querySelector('i');
    if(passInput.type === 'password') {
        passInput.type = 'text';
        icon.classList.remove('fa-eye');
        icon.classList.add('fa-eye-slash');
    } else {
        passInput.type = 'password';
        icon.classList.remove('fa-eye-slash');
        icon.classList.add('fa-eye');
    }
});

// ---- SIDEBAR TOGGLE (MOBILE) ----
document.getElementById('btnToggleSidebar')?.addEventListener('click', function() {
    document.getElementById('sidebar').classList.toggle('show');
});

// Hide sidebar when clicking outside on mobile
document.addEventListener('click', function(e) {
    const sidebar = document.getElementById('sidebar');
    const toggleBtn = document.getElementById('btnToggleSidebar');
    if(window.innerWidth < 992 && sidebar?.classList.contains('show') && !sidebar.contains(e.target) && !toggleBtn.contains(e.target)) {
        sidebar.classList.remove('show');
    }
});

// ---- SEARCH HOC VIEN ----
document.getElementById('search_HV')?.addEventListener('keyup', function(e) {
    if(e.key === 'Enter' || this.value === '' || this.value.length >= 3) {
        // debounce search
        clearTimeout(this.timer);
        this.timer = setTimeout(() => {
            loadHocVien();
        }, 300);
    }
});

window.saveAllDiem = async function() {
    const filter = document.getElementById('filterKhoaHoc_Diem');
    const maKhoa = filter.value;
    const soMd = parseInt(filter.options[filter.selectedIndex].getAttribute('data-somd')) || 5;

    // Validate
    const invalidInputs = document.querySelectorAll('.diem-input.is-invalid');
    if(invalidInputs.length > 0) {
        alert("Có ô nhập điểm không hợp lệ (Phải từ 0 đến 10). Vui lòng sửa trước khi lưu.");
        return;
    }

    const btnSave = document.getElementById('btnSaveAllDiem');
    const status = document.getElementById('diemStatus');
    btnSave.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>ĐANG LƯU...';
    btnSave.disabled = true;

    const supabaseMod = await import('./supabase-client.js');

    // Gather all students
    const rows = document.querySelectorAll('#diemContainer tbody tr');
    let hasError = false;

    for(let row of rows) {
        const maHv = row.id.replace('row_', '');
        const dataToSave = { MaHV: maHv };
        for(let i=1; i<=soMd; i++) {
            const input = row.querySelector(`input[data-md="${i}"]`);
            if(input) {
                dataToSave[`DiemMD${i}`] = input.value !== '' ? parseFloat(input.value) : null;
            }
        }

        // We do NOT send TongKet or XepLoai, let backend handle it
        const { data } = await supabaseMod.supabase.rpc('admin_save_hocvien', { p_token: currentToken, p_mode: 'edit', p_data: dataToSave });
        if(!data.success) {
            hasError = true;
            console.error("Lỗi lưu điểm HV " + maHv, data.message);
        }
    }

    if(hasError) {
        alert("Đã xảy ra lỗi khi lưu một số học viên. Vui lòng kiểm tra lại.");
    } else {
        status.innerHTML = '<i class="fas fa-check-circle me-1"></i>Đã lưu thành công';
        status.className = 'text-success small me-3 fw-bold';
        // Reload to get server-calculated grades
        setTimeout(() => loadBangDiem(), 500);
    }

    btnSave.innerHTML = '<i class="fas fa-save me-2"></i>Lưu Bảng Điểm';
    btnSave.disabled = false;
}

const appCauHinh = {
    modal: null,
    init: function() {
        this.modal = new bootstrap.Modal(document.getElementById('mdlCauHinh'));
        document.getElementById('frmCauHinh').addEventListener('submit', this.save.bind(this));
    },
    showModal: async function() {
        if(!this.modal) this.init();
        document.getElementById('cauhinhAlert').classList.add('d-none');

        const supabaseMod = await import('./supabase-client.js');
        const { data } = await supabaseMod.supabase.from('CauHinh').select('*').limit(1);
        if (data && data.length > 0) {
            const ch = data[0];
            document.getElementById('c_TenSite').value = ch.TenSite || '';
            document.getElementById('c_LogoUrl').value = ch.LogoUrl || '';
            document.getElementById('c_MauChuDao').value = ch.MauChuDao || '#004085';
            document.getElementById('c_ChanTrang').value = ch.ChanTrang || '';
        }

        this.modal.show();
    },
    save: async function(e) {
        e.preventDefault();
        const dataObj = {
            TenSite: document.getElementById('c_TenSite').value,
            LogoUrl: document.getElementById('c_LogoUrl').value,
            MauChuDao: document.getElementById('c_MauChuDao').value,
            ChanTrang: document.getElementById('c_ChanTrang').value
        };
        const supabaseMod = await import('./supabase-client.js');
        const { data, error } = await supabaseMod.supabase.rpc('admin_update_cauhinh', { p_token: currentToken, p_data: dataObj });

        const alertBox = document.getElementById('cauhinhAlert');
        if(error || (data && !data.success)) {
            alertBox.innerText = error ? error.message : data.message;
            alertBox.classList.remove('d-none');
        } else {
            this.modal.hide();
            alert('Lưu cấu hình thành công! Hãy tải lại trang để áp dụng.');
            window.location.reload();
        }
    }
};

window.xemHocVienDetail = async function(maHv) {
    const supabaseMod = await import('./supabase-client.js');
    const { data } = await supabaseMod.supabase.rpc('get_hocvien', { p_token: currentToken });
    const hv = data.data.find(h => h.MaHV === maHv);
    if(!hv) return;

    const modal = new bootstrap.Modal(document.getElementById('mdlHocVienDetail'));
    const content = document.getElementById('detailHocVienContent');

    content.innerHTML = `
        <div class="col-md-6"><strong>Mã HV:</strong> ${hv.MaHV}</div>
        <div class="col-md-6"><strong>Họ tên:</strong> ${escapeHTML(hv.HoTen)}</div>
        <div class="col-md-6"><strong>Giới tính:</strong> ${escapeHTML(hv.GioiTinh || '')}</div>
        <div class="col-md-6"><strong>Ngày sinh:</strong> ${hv.NgaySinh || ''}</div>
        <div class="col-md-6"><strong>CCCD:</strong> ${escapeHTML(hv.SoCC || '')}</div>
        <div class="col-md-6"><strong>Ngày/Nơi cấp:</strong> ${hv.NgayCC || ''} - ${escapeHTML(hv.NoiCC || '')}</div>
        <div class="col-md-6"><strong>SĐT:</strong> ${escapeHTML(hv.Dienthoai || '')}</div>
        <div class="col-md-6"><strong>Trạng thái:</strong> <span class="badge ${hv.TrangThaiDuyet==='Đã duyệt'?'bg-success':'bg-warning text-dark'}">${escapeHTML(hv.TrangThaiDuyet)}</span></div>
        <div class="col-md-6"><strong>Dân tộc / Tôn giáo:</strong> ${escapeHTML(hv.DanToc || '')} / ${escapeHTML(hv.TonGiao || '')}</div>
        <div class="col-md-6"><strong>Trình độ VH:</strong> ${escapeHTML(hv.TrinhDoVH || '')}</div>
        <div class="col-12"><strong>HKTT:</strong> ${escapeHTML(hv.HKTT || '')}</div>
        <div class="col-12"><strong>Nơi cư trú:</strong> ${escapeHTML(hv.NoiCuTru || '')}</div>
        <div class="col-12"><strong>Việc làm mong muốn:</strong> ${escapeHTML(hv.ViecLamSauDaoTao || '')}</div>
        <div class="col-12"><strong>Khóa đã tham gia:</strong> ${hv.KhoaDaThamGia ? hv.KhoaDaThamGia.join(', ') : 'Chưa có'}</div>
        <div class="col-12"><strong>Ghi chú:</strong> <div style="white-space: pre-wrap;">${escapeHTML(hv.GhiChu || '')}</div></div>
    `;

    const btnApprove = document.getElementById('btnDetailApprove');
    const btnEdit = document.getElementById('btnDetailEdit');

    // Only Admin/Giáo vụ can approve
    if (['Ban Giám đốc', 'Giáo vụ'].includes(currentUserRole)) {
        btnEdit.classList.remove('d-none');
        btnEdit.onclick = () => { modal.hide(); window.editHocVien(maHv); };

        if (hv.TrangThaiDuyet === 'Chờ duyệt') {
            btnApprove.classList.remove('d-none');
            btnApprove.onclick = () => { modal.hide(); window.duyetHocVien(maHv); };
        } else {
            btnApprove.classList.add('d-none');
        }
    } else {
        btnApprove.classList.add('d-none');
        btnEdit.classList.add('d-none');
    }

    modal.show();
};
