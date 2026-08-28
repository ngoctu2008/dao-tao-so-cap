import { createClient } from '@supabase/supabase-js';
import { SUPABASE_URL, SUPABASE_ANON_KEY, SENTRY_DSN } from './config.js';

if (!SUPABASE_URL || SUPABASE_URL === 'YOUR_SUPABASE_URL_HERE' || SUPABASE_URL === 'undefined') {
    throw new Error('SUPABASE_URL_MISSING');
}

// Khởi tạo Supabase client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export async function rpcWithRetry(rpcName, params, retries = 3, timeoutMs = 15000) {
    let lastError;
    for (let i = 0; i < retries; i++) {
        try {
            const result = await Promise.race([
                supabase.rpc(rpcName, params),
                new Promise((_, reject) => setTimeout(() => reject(new Error('TIMEOUT')), timeoutMs))
            ]);
            return result;
        } catch (error) {
            lastError = error;
            if (error.message === 'TIMEOUT' || error.message.includes('fetch')) {
                console.warn(`RPC ${rpcName} thử lại lần ${i + 1}/${retries}...`);
                if (i < retries - 1) {
                    await new Promise(res => setTimeout(res, 1000 * (i + 1))); // Exponential backoff
                }
            } else {
                throw error;
            }
        }
    }
    throw lastError;
}

// Global Sentry Setup (if DSN is provided)
if (SENTRY_DSN) {
    // Dynamically load Sentry script and initialize
    const script = document.createElement('script');
    script.src = "https://browser.sentry-cdn.com/7.73.0/bundle.min.js";
    script.crossOrigin = "anonymous";
    script.onload = () => {
        Sentry.init({
            dsn: SENTRY_DSN,
            tracesSampleRate: 1.0,
        });
    };
    document.head.appendChild(script);
}
