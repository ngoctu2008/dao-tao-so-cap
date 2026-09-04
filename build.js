const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { Client } = require('pg');

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY;
const sentryDsn = process.env.NEXT_PUBLIC_SENTRY_DSN || '';

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ THIẾU BIẾN MÔI TRƯỜNG: Vui lòng thiết lập NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY trên Vercel trước khi Deploy.");
  process.exit(1);
}

if (!process.env.POSTGRES_URL) {
  console.warn("⚠️ CẢNH BÁO: Không tìm thấy biến môi trường POSTGRES_URL. Quá trình tự động tạo bảng (migration) sẽ bị BỎ QUA. Ứng dụng có thể báo lỗi kết nối nếu bạn chưa tạo database thủ công.");
}

const configContent = `
const SUPABASE_URL = '${supabaseUrl}';
const SUPABASE_ANON_KEY = '${supabaseKey}';
const SENTRY_DSN = '${sentryDsn}';

export { SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN };
`;

fs.writeFileSync(path.join(__dirname, 'src/config.js'), configContent.trim());
console.log('✅ File config.js đã được tạo thành công tại src/config.js!');

try {
  console.log('📦 Bundling supabase-client.js...');
  execSync('npx esbuild src/supabase-client.js --bundle --format=esm --outfile=public/js/supabase-client.js --minify', { stdio: 'inherit' });
  console.log('✅ Bundling hoàn tất!');
} catch (error) {
  console.error('❌ Lỗi bundling:', error);
  process.exit(1);
}

// Chạy tự động migrations database nếu có biến môi trường POSTGRES_URL
async function runMigrations() {
  const connectionString = process.env.POSTGRES_URL;
  if (!connectionString) {
    console.log('ℹ️ Không tìm thấy biến môi trường POSTGRES_URL. Bỏ qua bước tự động chạy database migrations.');
    return;
  }

  console.log('🚀 Bắt đầu tự động chạy migration database (khởi tạo bảng và admin)...');
  const client = new Client({
    connectionString: connectionString,
    ssl: { rejectUnauthorized: false } // Bắt buộc khi kết nối tới Supabase từ bên ngoài
  });

  try {
    await client.connect();
    console.log('✅ Đã kết nối tới Database.');

    const migrationsDir = path.join(__dirname, 'supabase/migrations');
    if (!fs.existsSync(migrationsDir)) {
      console.log('ℹ️ Không tìm thấy thư mục migration (supabase/migrations). Bỏ qua.');
      return;
    }

    const files = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort(); // Chạy tuần tự theo tên file

    for (const file of files) {
      console.log(`⏳ Đang chạy migration: ${file}...`);
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      try {
        await client.query(sql);
        console.log(`✅ Chạy thành công: ${file}`);
      } catch (err) {
        // Có thể bảng đã tồn tại, in ra cảnh báo nhưng không dừng quá trình build
        console.warn(`⚠️ Có lỗi hoặc cảnh báo khi chạy ${file} (có thể bảng đã tồn tại):`, err.message);
      }
    }

    console.log('🎉 Hoàn tất quá trình khởi tạo Database!');
  } catch (err) {
    console.error('❌ Lỗi kết nối hoặc chạy database migrations:', err.message);
  } finally {
    await client.end();
  }
}

// Thực thi
runMigrations().then(() => {
  console.log('✅ Build thành công!');
}).catch(console.error);
