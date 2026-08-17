const fs = require('fs');
const path = require('path');

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error("❌ THIẾU BIẾN MÔI TRƯỜNG: Vui lòng thiết lập NEXT_PUBLIC_SUPABASE_URL và NEXT_PUBLIC_SUPABASE_PUBLISHABLE_DEFAULT_KEY trên Vercel trước khi Deploy.");
  process.exit(1);
}

const configContent = `
const SUPABASE_URL = '${supabaseUrl}';
const SUPABASE_ANON_KEY = '${supabaseKey}';

export { SUPABASE_URL, SUPABASE_ANON_KEY };
`;

fs.writeFileSync(path.join(__dirname, 'public/js/config.js'), configContent.trim());
console.log('✅ File config.js đã được tạo thành công tại public/js/config.js!');
