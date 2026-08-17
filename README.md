# Hệ Thống Quản Lý Đào Tạo Nghề (Supabase + Vercel)

Đây là ứng dụng quản lý đào tạo nghề nghiệp được xây dựng bằng giao diện HTML/JS thuần (Bootstrap 5) và cơ sở dữ liệu Supabase (PostgreSQL).

Dự án hỗ trợ **triển khai tự động 1-click** lên Vercel.

## 🚀 Hướng Dẫn Cài Đặt (Triển khai tự động lên Vercel)

### Bước 1: Chuẩn bị Cơ Sở Dữ Liệu (Supabase)

1. Truy cập [Supabase.com](https://supabase.com/) và tạo một Project mới.
2. Tại trang quản trị Supabase, vào mục **SQL Editor**, tạo một Query mới.
3. Copy toàn bộ nội dung trong file `supabase/migrations/20240101000000_init_schema.sql` của dự án này và dán vào SQL Editor, sau đó nhấn **Run** để tự động tạo bảng, hàm RPC và dữ liệu cấu hình.
4. Vào phần **Project Settings -> API**. Lưu lại 2 thông tin sau:
   - **Project URL**
   - **Project API Keys (anon / public)**

### Bước 2: Deploy lên Vercel

1. Tạo tài khoản miễn phí tại [Vercel.com](https://vercel.com) (nếu chưa có).
2. Tự động sao chép (Fork) repository này về tài khoản GitHub của bạn.
3. Liên kết repository vừa fork với Vercel và triển khai. *(Quá trình build sẽ báo lỗi nếu bạn chưa khai báo biến môi trường, hãy thực hiện bước 4)*.
4. Tại màn hình cài đặt của Vercel (Project Settings > Environment Variables), hãy điền 2 biến môi trường đã lưu ở Bước 1:
   - `NEXT_PUBLIC_SUPABASE_URL` = (Điền Project URL của Supabase)
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` = (Điền Project API Keys `anon` của Supabase)
5. Nhấn **Redeploy** và chờ 2 -> 3 phút để hệ thống tự động thiết lập.

---

### Thông Tin Đăng Nhập Mặc Định

Sau khi Deploy thành công, hãy truy cập vào đường link Vercel cung cấp để sử dụng hệ thống.

- **Tên đăng nhập:** `admin`
- **Mật khẩu:** `admin123`

⚠️ **CẢNH BÁO BẢO MẬT:** Ngay sau khi đăng nhập lần đầu tiên, hệ thống sẽ yêu cầu bạn đổi mật khẩu. Hãy đổi ngay lập tức để bảo vệ dữ liệu học viên (CCCD, SĐT...). Không được chia sẻ mật khẩu admin cho người khác.
