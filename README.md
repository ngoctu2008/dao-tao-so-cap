# Hệ thống Quản lý Đào tạo Nghề

Ứng dụng quản lý đào tạo nghề dành cho trung tâm giáo dục nghề nghiệp – giáo dục thường xuyên. Dự án cung cấp giao diện quản trị tĩnh bằng **HTML, CSS và JavaScript ES Modules**, sử dụng **Bootstrap 5** cho các thành phần giao diện và **Supabase PostgreSQL** làm lớp dữ liệu phía sau.

Ứng dụng có thể triển khai trên **Vercel** dưới dạng static site. Script build của dự án tạo tệp cấu hình Supabase từ biến môi trường tại thời điểm build; vì vậy URL Supabase và publishable/anon key phải được khai báo trước khi chạy `npm run build` hoặc deploy.

> **Trạng thái triển khai:** Repository hiện là một ứng dụng frontend tĩnh kết nối trực tiếp tới các Database Functions/RPC của Supabase. Trước khi dùng với dữ liệu học viên thật, cần rà soát và hardening thêm về phân quyền, giới hạn đăng ký công khai, quản lý session và bảo vệ dữ liệu cá nhân.

## 1. Chức năng chính

### 1.1. Cổng đăng ký học nghề công khai

Trang `public/DangKy.html` cung cấp quy trình đăng ký học nghề bốn bước. Người đăng ký chọn khóa đang tuyển sinh, nhập thông tin cá nhân, giấy tờ và nơi cư trú, khai báo định hướng việc làm, xác nhận đồng ý rồi gửi hồ sơ.

Hệ thống kiểm tra khóa học còn ở trạng thái `Tuyển sinh`, tạo mã học viên, lưu hồ sơ với trạng thái ban đầu `Chờ duyệt` và gửi thông báo cho người phụ trách khóa hoặc tài khoản quản trị. Sau khi đăng ký thành công, màn hình hiển thị mã hồ sơ để người đăng ký lưu lại.

### 1.2. Đăng nhập và phân quyền

Trang `public/index.html` là cổng quản trị dành cho cán bộ. Người dùng đăng nhập bằng tài khoản được tạo trong bảng `Users`. Hệ thống sử dụng các Database Functions của Supabase để kiểm tra tài khoản, tạo session token và tải dữ liệu theo vai trò.

Các vai trò được sử dụng trong migration gồm:

| Vai trò | Phạm vi chức năng chính |
|---|---|
| `Ban Giám đốc` | Xem dashboard, quản lý khóa học, học viên, điểm, danh mục và người dùng |
| `Giáo vụ` | Quản lý khóa học và hồ sơ học viên, theo dõi đào tạo và xử lý nghiệp vụ được cấp quyền |
| `Giáo viên` | Xem các khóa/lớp được phân công, xem và cập nhật dữ liệu trong phạm vi lớp phụ trách |

Việc ẩn/hiện menu trên frontend chỉ có tác dụng cải thiện trải nghiệm. Phân quyền thực tế phải được kiểm tra trong các RPC ở database.

### 1.3. Dashboard tổng quan

Dashboard hiển thị các chỉ số tổng hợp như số hồ sơ chờ duyệt, học viên đang học, học viên tốt nghiệp và khóa đang mở. Màn hình cũng có bảng hồ sơ mới cần xử lý, lối tắt tạo khóa học/thêm học viên/nhập điểm và khu vực thông báo.

### 1.4. Quản lý khóa học và lớp học

Cán bộ có quyền có thể tạo, sửa và xóa khóa học. Dữ liệu khóa học gồm mã khóa, tên khóa, nghề đào tạo, giáo viên chủ nhiệm, trạng thái, địa điểm và khoảng thời gian đào tạo. Hệ thống hỗ trợ tạo mã QR dẫn tới trang đăng ký theo khóa và xem danh sách học viên của khóa.

### 1.5. Quản lý hồ sơ học viên

Màn hình học viên hỗ trợ tìm kiếm, lọc theo khóa và trạng thái duyệt, xem/sửa hồ sơ, duyệt hồ sơ và xóa hồ sơ theo quyền. Dữ liệu bao gồm thông tin cá nhân, CCCD, trình độ văn hóa, dân tộc, tôn giáo, hộ khẩu thường trú, nơi cư trú, số điện thoại, đối tượng chính sách và định hướng việc làm sau đào tạo.

### 1.6. Nhập điểm và kết quả đào tạo

Màn hình nhập điểm tải danh sách học viên theo khóa/lớp và cho phép nhập điểm theo mô-đun. Người dùng có thể lưu toàn bộ bảng điểm. Việc phân quyền cập nhật điểm được xử lý trong Database Function dựa trên vai trò và lớp được phân công.

### 1.7. Danh mục, người dùng và thông báo

Tài khoản `Ban Giám đốc` có thể quản lý người dùng, tạo tài khoản, khóa/mở tài khoản và xem thông tin người dùng. Hệ thống có các danh mục nghề đào tạo, đối tượng chính sách và cấu hình trung tâm trong database. Thông báo có thể được đánh dấu đã đọc.

## 2. Công nghệ và kiến trúc

| Thành phần | Công nghệ/thư mục | Vai trò |
|---|---|---|
| Giao diện | HTML, CSS, JavaScript ES Modules | Các trang quản trị và đăng ký công khai |
| UI framework | Bootstrap 5 qua CDN | Grid, form, modal, dropdown và responsive layout |
| Icon/tiện ích | Font Awesome, AOS, QRCode.js qua CDN | Icon, hiệu ứng và tạo QR |
| Dữ liệu | Supabase PostgreSQL | Bảng nghiệp vụ, migration và Database Functions |
| Client database | `@supabase/supabase-js` qua CDN | Khởi tạo client và gọi RPC |
| Build | `build.js`, Node.js | Sinh `public/js/config.js` từ biến môi trường |
| Hosting | Vercel | Build và phục vụ thư mục `public` |

Cấu trúc thư mục quan trọng:

```text
.
├── public/
│   ├── index.html                  # Giao diện quản trị
│   ├── DangKy.html                 # Cổng đăng ký học nghề
│   ├── css/                        # CSS quản trị và đăng ký
│   └── js/
│       ├── app.js                  # Logic quản trị, RBAC và CRUD
│       ├── dangky.js               # Wizard đăng ký và validation
│       ├── supabase-client.js      # Khởi tạo Supabase client
│       ├── config.example.js       # Mẫu cấu hình local
│       └── config.js               # Sinh bởi build.js, không commit secret
├── supabase/
│   └── migrations/
│       └── 20240101000000_init_schema.sql
├── build.js                        # Kiểm tra env và sinh config.js
├── package.json
├── vercel.json                     # Build/output/security headers
└── README.md
```

## 3. Yêu cầu hệ thống

Để cài đặt và build local, cần có:

| Yêu cầu | Khuyến nghị |
|---|---|
| Node.js | Phiên bản LTS hiện hành |
| npm | Đi kèm Node.js |
| Supabase | Một project có quyền mở SQL Editor |
| Git | Dùng để clone repository |
| Trình duyệt | Chromium, Edge, Firefox hoặc Safari hiện hành |

Dự án không có dependency npm runtime trong `package.json`; các thư viện frontend chính được tải qua CDN. Tuy nhiên cần chạy bước build bằng Node.js để tạo file cấu hình Supabase.

## 4. Cài đặt database trên Supabase

### Bước 1: Tạo project

Truy cập [Supabase](https://supabase.com), đăng nhập và tạo một project mới. Chờ project hoàn tất khởi tạo, sau đó mở **Project Settings → API** để lấy **Project URL** và **Publishable key/anon key**.

Không đưa `service_role` key vào frontend, Git repository hoặc biến môi trường public. Frontend chỉ được dùng publishable/anon key; quyền thực tế phải được giới hạn bằng RLS, quyền thực thi function và kiểm tra vai trò trong database.

### Bước 2: Chạy migration

Mở **SQL Editor → New query**, copy toàn bộ nội dung lần lượt các tệp sau rồi nhấn **Run** theo thứ tự từ trên xuống dưới:

```text
supabase/migrations/20240101000000_init_schema.sql
supabase/migrations/20240822000000_fix_hocvien_full_fields.sql
```

Migration tạo các bảng nghiệp vụ như `Users`, `UserSessions`, `DoiTuong`, `Nghedaotao`, `Khoahoc`, `Hocvien`, `Diem`, `ThongBao` và `CauHinh`. Migration đồng thời tạo các Database Functions/RPC cho đăng nhập, xác thực session, dashboard, khóa học, học viên, điểm, đăng ký công khai, quản lý người dùng và thông báo.

Supabase cho phép tạo Database Functions trực tiếp bằng SQL Editor và gọi chúng từ JavaScript bằng `supabase.rpc()` [1]. Vì migration của dự án có nhiều function phụ thuộc vào thứ tự tạo bảng, nên nên chạy toàn bộ file trong một lần thay vì tách thủ công thành nhiều đoạn.

### Bước 3: Nạp lại Schema Cache

Nếu bạn gặp lỗi kết nối (PGRST202 hoặc hàm không tồn tại), hãy vào **Project Settings → API** và nhấn **Reload schema cache**, hoặc chạy lệnh sau trong SQL Editor để PostgREST nạp lại danh sách hàm:
```sql
NOTIFY pgrst, 'reload schema';
```

### Bước 4: Kiểm tra database

Sau khi chạy migration và reload schema, kiểm tra nhanh trong Supabase bằng các truy vấn sau:

```sql
select * from public."Users";
select * from public."Khoahoc";
select public_get_khoatuyensinh();
```

Tên bảng được tạo trong migration cần được giữ nguyên. Nếu project Supabase đã có dữ liệu hoặc object trùng tên, hãy tạo project/database riêng cho môi trường thử nghiệm trước khi chạy migration.

## 5. Cấu hình và chạy local

### Cách A: Build local bằng biến môi trường

Từ thư mục gốc của repository, chạy:

```bash
git clone https://github.com/ngoctu2008/dao-dao-so-cap.git
cd dao-dao-so-cap

export NEXT_PUBLIC_SUPABASE_URL="https://<project-ref>.supabase.co"
export NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY="<publishable-or-anon-key>"

npm run build
```

Script `build.js` kiểm tra hai biến môi trường trên và sinh file `public/js/config.js`. Nội dung sinh ra có dạng:

```js
const SUPABASE_URL = 'https://<project-ref>.supabase.co';
const SUPABASE_ANON_KEY = '<publishable-or-anon-key>';

export { SUPABASE_URL, SUPABASE_ANON_KEY };
```

Sau khi build, có thể dùng một static server để mở thư mục `public`. Ví dụ với `npx serve`:

```bash
npx serve public
```

Sau đó mở URL local được terminal hiển thị. Không nên mở trực tiếp bằng `file://` vì ES Modules và các request tới Supabase có thể bị giới hạn bởi chính sách trình duyệt.

### Cách B: Tạo cấu hình thủ công để kiểm thử giao diện

Sao chép file mẫu:

```bash
cp public/js/config.example.js public/js/config.js
```

Mở `public/js/config.js` và điền URL/key của Supabase. Cách này phù hợp để xem nhanh giao diện, nhưng khi triển khai chính thức nên dùng `build.js` và biến môi trường để tránh đưa cấu hình vào source control.

File `public/js/config.js` đã chứa key client thì không được commit lên Git nếu repository dùng chung hoặc public. Có thể kiểm tra trước khi commit:

```bash
git status --short
git diff -- public/js/config.js
```

## 6. Triển khai lên Vercel

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https%3A%2F%2Fgithub.com%2Fngoctu2008%2Fdao-tao-so-cap&env=NEXT_PUBLIC_SUPABASE_URL,NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY,POSTGRES_URL)

1. Tạo tài khoản miễn phí tại [Vercel.com](https://vercel.com) (nếu chưa có).
2. Tự động sao chép (Fork) repository này về tài khoản GitHub của bạn.
3. Liên kết repository vừa fork với Vercel và triển khai. (Quá trình build sẽ báo lỗi nếu bạn chưa khai báo biến môi trường, hãy thực hiện bước 4).
4. Tại màn hình cài đặt của Vercel (**Project Settings > Environment Variables**), hãy điền **BẮT BUỘC** 3 biến môi trường (lấy từ Supabase) để hệ thống tự động thiết lập:
   - `NEXT_PUBLIC_SUPABASE_URL` = (Điền Project URL của Supabase)
   - `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY` = (Điền Project API Keys anon của Supabase)
   - `POSTGRES_URL` = (Điền chuỗi kết nối Connection String (URI) của Supabase. Bạn lấy ở mục **Project Settings -> Database -> Connection string -> URI**. VD: `postgresql://postgres.[project-ref]:[password]@[host]:[port]/[db-name]`)
5. Nhấn **Redeploy** và chờ 2 -> 3 phút để hệ thống tự động thiết lập Database, tạo tài khoản Admin và build giao diện.

Cấu hình của dự án đã được tích hợp sẵn trong `vercel.json` (build command, output directory `public`, headers).

### Bước 6: Kiểm tra deployment

Sau khi deployment hoàn tất, kiểm tra lần lượt:

| URL/chức năng | Nội dung cần kiểm tra |
|---|---|
| `/` hoặc `/index.html` | Màn hình đăng nhập quản trị |
| `/DangKy.html` | Form đăng ký công khai tải được danh sách khóa tuyển sinh |
| Đăng nhập | Tài khoản được tạo trong bảng `Users` đăng nhập được |
| Dashboard | Chỉ số và thông báo tải được từ Supabase |
| CRUD | Người dùng đúng vai trò có thể thực hiện thao tác được cấp quyền |
| Console/Network | Không có lỗi thiếu `config.js`, CSP, CORS hoặc RPC |

## 7. Tài khoản mẫu và bước bảo mật bắt buộc

Migration hiện tạo tài khoản mẫu:

| Tên đăng nhập | Vai trò | Mật khẩu khởi tạo |
|---|---|---|
| `admin` | `Ban Giám đốc` | `admin123` |

Đây là thông tin mặc định có trong mã nguồn và chỉ nên dùng để khởi tạo môi trường phát triển hoặc kiểm thử. Ngay sau lần đăng nhập đầu tiên, hãy đổi mật khẩu bằng chức năng **Đổi mật khẩu** và không sử dụng lại mật khẩu mẫu trong production.

Trước khi đưa vào vận hành thật, cần thay đổi hoặc loại bỏ tài khoản mặc định, tạo tài khoản riêng cho từng cán bộ, khóa các tài khoản không còn sử dụng, kiểm tra quyền của từng RPC và bảo vệ dữ liệu CCCD/số điện thoại. Không cấp `service_role` key cho trình duyệt.

## 8. Quy trình sử dụng đề xuất

Quản trị viên khởi tạo danh mục nghề, đối tượng chính sách và tài khoản cán bộ. Giáo vụ tạo khóa học, chọn nghề, thời gian, địa điểm và giáo viên phụ trách, sau đó chuyển trạng thái sang `Tuyển sinh` để cổng công khai hiển thị khóa.

Người học truy cập `DangKy.html`, chọn khóa, hoàn thành biểu mẫu và gửi hồ sơ. Hồ sơ được tạo ở trạng thái `Chờ duyệt`; cán bộ phụ trách nhận thông báo và kiểm tra thông tin. Giáo vụ hoặc người có quyền duyệt hồ sơ, cập nhật trạng thái và bổ sung thông tin khi cần.

Trong quá trình đào tạo, giáo viên xem các lớp được phân công và nhập điểm. Giáo vụ/quản trị theo dõi dashboard, kiểm tra dữ liệu và sử dụng báo cáo hoặc dữ liệu bảng để phục vụ quản lý. Khi kết thúc tuyển sinh, khóa học được chuyển khỏi trạng thái `Tuyển sinh` để cổng công khai không tiếp tục nhận hồ sơ mới.

## 9. Xử lý sự cố thường gặp

| Hiện tượng | Nguyên nhân thường gặp | Cách xử lý |
|---|---|---|
| `THIẾU BIẾN MÔI TRƯỜNG` khi build | Chưa khai báo một trong hai biến Supabase | Kiểm tra tên biến chính xác, giá trị environment và chạy lại build |
| Trang báo lỗi không tải được `config.js` | Chưa chạy build hoặc file cấu hình không tồn tại | Chạy `npm run build` với đủ biến hoặc tạo `config.js` từ file mẫu để kiểm thử |
| Form đăng ký không có khóa học | Chưa có khóa ở trạng thái `Tuyển sinh`, migration chưa chạy hoặc RPC lỗi | Kiểm tra bảng `Khoahoc`, trạng thái khóa, Supabase Logs và Network tab |
| Đăng nhập thất bại | Tài khoản bị khóa, sai mật khẩu hoặc database chưa có seed admin | Kiểm tra bảng `Users`, trạng thái và migration; không chia sẻ mật khẩu trên log |
| CRUD bị `Forbidden` | Vai trò hiện tại không được phép thao tác | Kiểm tra role của user và logic phân quyền trong RPC |
| Deployment thành công nhưng gọi Supabase lỗi | URL/key sai, CSP/CORS hoặc biến chưa áp dụng cho environment đang chạy | Kiểm tra Environment Variables, Redeploy và Console/Network của trình duyệt |
| Mở file HTML bằng `file://` bị lỗi module | Trình duyệt giới hạn ES Modules/CORS trên file local | Dùng static server như `npx serve public` |

Khi chẩn đoán lỗi, không ghi URL chứa token session, key, mật khẩu, CCCD hoặc số điện thoại vào issue/log công khai. Supabase khuyến nghị kiểm tra quyền Data API, RLS và quyền thực thi function trước khi cấp quyền cho client [1].

## 10. Kiểm thử trước khi phát hành

Có thể chạy các kiểm tra cơ bản sau:

```bash
npm run build
node --check build.js
node --check public/js/app.js
node --check public/js/dangky.js
node --check public/js/supabase-client.js
```

Kết quả build hợp lệ phải tạo được `public/js/config.js`. Sau đó cần kiểm thử thủ công trên desktop và mobile với các kịch bản: đăng nhập thành công/thất bại, đổi mật khẩu, đăng ký thiếu trường, đăng ký trùng CCCD, đăng ký vào khóa đã đóng, duyệt hồ sơ, nhập điểm không hợp lệ, lưu điểm, khóa tài khoản và đăng xuất.

Khi thay đổi schema hoặc RPC, nên kiểm thử trên Supabase project riêng trước, lưu migration mới thay vì sửa âm thầm migration đã chạy, rồi cập nhật tài liệu cho tên function/tham số mới. Có thể dùng Supabase CLI để sinh type database khi dự án chuyển sang TypeScript; tài liệu JavaScript chính thức mô tả cả `supabase.rpc()` và quy trình sinh type từ schema [4].

## 11. Giới hạn và khuyến nghị nâng cấp

Phiên bản hiện tại phù hợp cho prototype hoặc triển khai nội bộ có kiểm soát. Vì frontend gọi trực tiếp các RPC và có cổng đăng ký công khai, nên trước production cần hoàn thiện rate limiting/chống spam, xác thực object-level authorization, session revoke, audit log, validation server-side, masking dữ liệu nhạy cảm, backup/restore và giám sát lỗi.

Nên bổ sung test tự động cho RPC, kiểm thử quyền theo từng role, CI build trên pull request, quản lý migration bằng Supabase CLI và tách rõ môi trường development/preview/production. Khi quy mô tăng, nên cân nhắc chuyển frontend sang TypeScript hoặc framework có kiểm soát kiểu, đồng thời sinh type từ schema database để giảm lỗi lệch tên cột và tham số.

## 12. License và đóng góp

Repository hiện chưa cung cấp thông tin license riêng. Trước khi phân phối hoặc sử dụng thương mại, chủ dự án cần bổ sung tệp `LICENSE` và quy định bản quyền đối với mã nguồn, logo, nội dung, thư viện CDN và dữ liệu mẫu.

Mọi thay đổi nên được thực hiện qua branch riêng và pull request. Pull request nên mô tả mục tiêu, migration liên quan, biến môi trường mới, ảnh hưởng quyền truy cập và kết quả kiểm thử. Không gửi secret, dữ liệu học viên thật hoặc file `config.js` chứa thông tin môi trường vào repository.

## Tài liệu tham khảo

[1]: https://supabase.com/docs/guides/database/functions "Supabase Database Functions"

[2]: https://vercel.com/docs/project-configuration "Vercel Project Configuration"

[3]: https://vercel.com/docs/environment-variables "Vercel Environment Variables"

[4]: https://supabase.com/docs/reference/javascript/introduction "Supabase JavaScript Client Reference"

[5]: https://github.com/ngoctu2008/dao-dao-so-cap "Repository dao-dao-so-cap"
