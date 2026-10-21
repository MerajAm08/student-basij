import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const url = Deno.env.get('SUPABASE_URL');
  const anon = Deno.env.get('SUPABASE_ANON_KEY');
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anon || !service) return new Response(JSON.stringify({ error: 'Server configuration missing' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const caller = createClient(url, anon, { global: { headers: { Authorization: authHeader } }, auth: { persistSession: false } });
  const adminClient = createClient(url, service, { auth: { persistSession: false } });
  const { data: { user }, error: userError } = await caller.auth.getUser();
  if (userError || !user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  const { data: actor } = await adminClient.from('profiles').select('role,is_active').eq('id', user.id).maybeSingle();
  if (!actor || actor.role !== 'admin' || !actor.is_active) return new Response(JSON.stringify({ error: 'Forbidden' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  try {
    const b = await req.json();
    const email = String(b.email || '').trim().toLowerCase();
    const password = String(b.password || '');
    const first_name = String(b.first_name || '').trim();
    const last_name = String(b.last_name || '').trim();
    // This deployment has one manually provisioned root admin; the admin UI only creates viewers.
    const role = 'viewer';
    if (!email.includes('@') || password.length < 12 || !first_name || !last_name) throw new Error('ایمیل معتبر، نام، نام خانوادگی و رمز حداقل ۱۲ نویسه لازم است.');
    if (b.national_code && !/^\d{10}$/.test(String(b.national_code))) throw new Error('کد ملی باید ۱۰ رقم باشد.');
    const { data, error } = await adminClient.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: { first_name, last_name } });
    if (error || !data.user) throw error || new Error('ساخت حساب ناموفق بود.');
    const { error: profileError } = await adminClient.from('profiles').insert({
      id: data.user.id, first_name, last_name, father_name: b.father_name || null,
      birth_date: b.birth_date || null, national_code: b.national_code || null,
      field_of_study: b.field_of_study || null, grade: b.grade || null, role, is_active: true,
    });
    if (profileError) { await adminClient.auth.admin.deleteUser(data.user.id); throw profileError; }
    await adminClient.from('audit_logs').insert({ actor_id: user.id, action: 'create_user', target_table: 'profiles', target_id: data.user.id });
    return new Response(JSON.stringify({ ok: true, user_id: data.user.id }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: e instanceof Error ? e.message : 'Request failed' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});
