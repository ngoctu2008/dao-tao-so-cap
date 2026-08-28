import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';
import { SUPABASE_URL, SUPABASE_ANON_KEY } from './config.js';

if (!SUPABASE_URL || SUPABASE_URL === 'YOUR_SUPABASE_URL_HERE') {
    throw new Error('SUPABASE_URL_MISSING');
}

// Khởi tạo Supabase client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
