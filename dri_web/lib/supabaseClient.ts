import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

if (!supabaseUrl || !supabaseKey) {
  throw new Error('Missing Supabase URL or Anon Key')
}

const supabase = createClient(supabaseUrl, supabaseKey)

// Fail-safe: if the browser has a broken session, Supabase can throw errors.
// This small helper ensures we can recover by signing out if needed.
if (typeof window !== 'undefined') {
  const checkSession = async () => {
    try {
      const { error } = await supabase.auth.getSession();
      if (error?.message?.includes('Refresh Token Not Found')) {
        console.warn('Stale session detected, clearing...');
        await supabase.auth.signOut();
        window.location.reload();
      }
    } catch (e) {
      console.error('Auth sync error:', e);
    }
  };
  checkSession();
}

export { supabase };
