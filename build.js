const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY;
const sentryDsn = process.env.NEXT_PUBLIC_SENTRY_DSN || '';

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ THIẾU BIẾN MÔI TRƯỜNG: Vui lòng thiết lập NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY trên Vercel trước khi Deploy.");
  process.exit(1);
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
