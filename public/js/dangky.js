

// DOM Elements
const loader = document.getElementById('loader');
const frmDangKy = document.getElementById('frmDangKy');
const cboMaKhoa = document.getElementById('MaKhoa');
const cboMaDoiTuong = document.getElementById('MaDoiTuong');
const msgAlert = document.getElementById('msgAlert');

// On Page Load
document.addEventListener('DOMContentLoaded', async () => {
    showLoader();
    try {
        await Promise.all([loadConfig(), loadKhoaHoc(), loadDoiTuong()]);

        // Auto select MaKhoa if passed via URL parameter
        const urlParams = new URLSearchParams(window.location.search);
        const urlMaKhoa = urlParams.get('makhoa');
        if(urlMaKhoa) {
            cboMaKhoa.value = urlMaKhoa;
        }

    } catch (error) {
        console.error("Lỗi khởi tạo:", error);
        if (!navigator.onLine) {
            showAlert('Mất kết nối mạng! Vui lòng kiểm tra kết nối Internet của bạn và tải lại trang.', 'danger');
        } else if (error.message && error.message.includes('SUPABASE_URL')) {
            showAlert('Hệ thống chưa được cấu hình. Vui lòng liên hệ quản trị viên.', 'warning');
        } else {
            showAlert('Lỗi kết nối cơ sở dữ liệu. Vui lòng thử lại sau!', 'danger');
        }
    } finally {
        hideLoader();
    }
});

// Load App Config
async function loadConfig() {
    const supabaseMod = await import('./supabase-client.js');
    const { data, error } = await supabaseMod.supabase.from('CauHinh').select('*');
    if (error) throw error;

    let config = {};
    data.forEach(item => config[item.ConfigKey] = item.ConfigValue);

    if(config['LogoUrl']) document.getElementById('site-logo').src = config['LogoUrl'];
    if(config['TenSite']) document.getElementById('site-title').innerText = config['TenSite'];
    if(config['ChanTrang']) document.getElementById('footer-text').innerText = config['ChanTrang'];

    if(config['MauChuDao']) {
        document.documentElement.style.setProperty('--primary-color', config['MauChuDao']);
    }
}

// Load Active Courses using Public RPC
async function loadKhoaHoc() {
    const supabaseMod = await import('./supabase-client.js');
    const { data, error } = await supabaseMod.rpcWithRetry('public_get_khoatuyensinh');

    if (error) throw error;
    if (!data.success) throw new Error("Lỗi tải danh sách khóa học");

    cboMaKhoa.innerHTML = '<option value="">-- Chọn lớp đăng ký --</option>';
    data.data.forEach(khoa => {
        const option = document.createElement('option');
        option.value = khoa.MaKhoa;
        option.textContent = `${khoa.TenKhoa} (${khoa.MaKhoa})`;
        cboMaKhoa.appendChild(option);
    });
}

// Load Policy Targets using Public RPC
async function loadDoiTuong() {
    const supabaseMod = await import('./supabase-client.js');
    const { data, error } = await supabaseMod.rpcWithRetry('public_get_doituong');

    if (error) throw error;
    if (!data.success) throw new Error("Lỗi tải danh sách đối tượng");

    data.data.forEach(dt => {
        const option = document.createElement('option');
        option.value = dt.MaDoiTuong;
        option.textContent = dt.TenDoiTuong;
        cboMaDoiTuong.appendChild(option);
    });
}

// Handle Form Submit

// Stepper Logic
let currentStep = 1;
const totalSteps = 4;

function updateStepper() {
    // Update Indicators
    document.querySelectorAll('.step-item').forEach(item => {
        const step = parseInt(item.getAttribute('data-step'));
        item.classList.remove('active', 'completed');
        if (step === currentStep) item.classList.add('active');
        if (step < currentStep) item.classList.add('completed');
    });

    // Update Content
    document.querySelectorAll('.wizard-step-content').forEach(content => {
        content.classList.remove('active');
    });
    document.getElementById(`step-${currentStep}`).classList.add('active');
    window.scrollTo(0, 0);
}

function validateCurrentStep() {
    const currentSection = document.getElementById(`step-${currentStep}`);
    const inputs = currentSection.querySelectorAll('input[required], select[required]');
    const errorList = document.getElementById('errorList');
    const errorSummary = document.getElementById('errorSummary');
    let isValid = true;

    errorList.innerHTML = '';

    inputs.forEach(input => {
        if (!input.checkValidity()) {
            isValid = false;
            input.classList.add('is-invalid');

            // Get label text for error message
            let labelText = 'Trường thông tin';
            const label = document.querySelector(`label[for="${input.id}"]`);
            if (label) labelText = label.textContent.replace('(*)', '').replace('*', '').trim();
            else if (input.name === 'GioiTinh') labelText = 'Giới tính';

            let errMsg = `Vui lòng nhập hợp lệ ${labelText}`;
            if(input.validity.valueMissing) errMsg = `Không được để trống ${labelText}`;
            if(input.validity.patternMismatch) errMsg = `${labelText} sai định dạng`;

            errorList.innerHTML += `<li><a href="#${input.id || input.name}" class="text-danger">${errMsg}</a></li>`;

            // Re-validate on input
            input.addEventListener('input', function() {
                if(this.checkValidity()) this.classList.remove('is-invalid');
            }, { once: true });

        } else {
            input.classList.remove('is-invalid');
        }
    });

    if(!isValid) {
        errorSummary.classList.remove('d-none');
    } else {
        errorSummary.classList.add('d-none');
    }

    return isValid;
}

document.querySelectorAll('.btn-next').forEach(btn => {
    btn.addEventListener('click', () => {
        if (validateCurrentStep() && currentStep < totalSteps) {
            currentStep++;
            updateStepper();
        }
    });
});

document.querySelectorAll('.btn-prev').forEach(btn => {
    btn.addEventListener('click', () => {
        if (currentStep > 1) {
            currentStep--;
            updateStepper();
        }
    });
});

// Sync Checkbox
document.getElementById('chkGiongHKTT').addEventListener('change', function() {
    const noiCuTru = document.getElementById('NoiCuTru');
    if(this.checked) {
        noiCuTru.value = document.getElementById('HKTT').value;
        noiCuTru.readOnly = true;
        noiCuTru.classList.remove('is-invalid');
    } else {
        noiCuTru.value = '';
        noiCuTru.readOnly = false;
    }
});

// Sync when HKTT changes if checkbox is checked
document.getElementById('HKTT').addEventListener('input', function() {
    if(document.getElementById('chkGiongHKTT').checked) {
        document.getElementById('NoiCuTru').value = this.value;
    }
});

// Update Submit Logic
frmDangKy.addEventListener('submit', async (e) => {
    e.preventDefault();

    // Honeypot check for bots
    const botCheck = document.getElementById('bot_check_field');
    if (botCheck && botCheck.value) {
        // Silently return success to fool the bot
        frmDangKy.classList.add('d-none');
        document.getElementById('successSection').classList.remove('d-none');
        return;
    }

    if (!validateCurrentStep()) return;

    const btnSubmit = document.getElementById('btnSubmitForm');
    btnSubmit.innerHTML = '<span class="spinner-border spinner-border-sm me-2"></span>ĐANG GỬI...';
    btnSubmit.disabled = true;
    document.getElementById('errorSummary').classList.add('d-none');

    try {

        const hocVienData = {
            MaKhoa: document.getElementById('MaKhoa').value,
            HoTen: document.getElementById('HoTen').value.toUpperCase(),
            GioiTinh: document.querySelector('input[name="GioiTinh"]:checked').value,
            NgaySinh: document.getElementById('NgaySinh').value,
            SoCC: document.getElementById('SoCC').value,
            NgayCC: document.getElementById('NgayCC').value || null,
            NoiCC: document.getElementById('NoiCC').value,
            DanToc: document.getElementById('DanToc').value,
            TonGiao: document.getElementById('TonGiao').value,
            TrinhDoVH: document.getElementById('TrinhDoVH').value,
            HKTT: document.getElementById('HKTT').value,
            NoiCuTru: document.getElementById('NoiCuTru').value,
            Dienthoai: document.getElementById('Dienthoai').value,
            MaDoiTuong: document.getElementById('MaDoiTuong').value ? parseInt(document.getElementById('MaDoiTuong').value) : null,
            ViecLamSauDaoTao: document.getElementById('ViecLamDuKien').value
        };

        const supabaseMod = await import('./supabase-client.js');
        const { data, error } = await supabaseMod.rpcWithRetry('register_hocvien', { p_data: hocVienData });

        if(error) throw error;
        if(!data.success) throw new Error(data.message || 'Lỗi không xác định');

        frmDangKy.classList.add('d-none');
        document.getElementById('stepper').classList.add('d-none');
        document.getElementById('successMaHV').innerText = data.mahv;
        document.getElementById('successState').classList.remove('d-none');

    } catch (error) {
        console.error("Lỗi đăng ký:", error);
        document.getElementById('errorList').innerHTML = `<li>${error.message}</li>`;
        document.getElementById('errorSummary').classList.remove('d-none');
    } finally {
        btnSubmit.innerHTML = '<i class="fas fa-paper-plane me-2"></i>GỬI HỒ SƠ';
        btnSubmit.disabled = false;
    }
});

// Utilities
function showLoader() { loader.style.display = 'flex'; }
function hideLoader() { loader.style.display = 'none'; }
function showAlert(message, type) {
    msgAlert.innerHTML = message;
    msgAlert.className = `alert alert-${type} mt-3`;
    msgAlert.classList.remove('d-none');
}
