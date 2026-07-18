// Syncs app_mail_settings → Supabase Auth custom SMTP (Management API).
// Auto-injected: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
// Custom secret: MANAGEMENT_ACCESS_TOKEN (Supabase personal access / management token)
// Project ref is derived from SUPABASE_URL.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function projectRefFromUrl(url: string): string {
  // https://<ref>.supabase.co
  const host = new URL(url).hostname
  return host.split('.')[0]
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'missing authorization' }, 401)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const accessToken = Deno.env.get('MANAGEMENT_ACCESS_TOKEN')
    if (!accessToken) {
      return json({ error: 'MANAGEMENT_ACCESS_TOKEN secret not set' }, 500)
    }
    const projectRef = projectRefFromUrl(supabaseUrl)

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: isAdmin, error: adminErr } = await userClient.rpc(
      'is_super_admin',
    )
    if (adminErr) throw adminErr
    if (isAdmin !== true) {
      return json({ error: 'not authorized' }, 403)
    }

    const adminClient = createClient(supabaseUrl, serviceKey)
    const { data: rows, error: settingsErr } = await adminClient.rpc(
      'get_mail_settings_internal',
    )
    if (settingsErr) throw settingsErr

    const row = Array.isArray(rows) ? rows[0] : rows
    if (!row?.smtp_user || !row?.smtp_pass) {
      return json(
        { error: 'smtp_user and smtp_pass must be set in app_mail_settings' },
        400,
      )
    }

    const fromEmail = (row.from_email || row.smtp_user).trim()
    const body = {
      external_email_enabled: true,
      smtp_host: row.smtp_host || 'smtp.gmail.com',
      smtp_port: String(row.smtp_port || 465),
      smtp_user: row.smtp_user.trim(),
      smtp_pass: row.smtp_pass,
      smtp_admin_email: fromEmail,
      smtp_sender_name: row.from_name || 'SYU Sri Lanka',
      smtp_max_frequency: 1,
    }

    const patchRes = await fetch(
      `https://api.supabase.com/v1/projects/${projectRef}/config/auth`,
      {
        method: 'PATCH',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(body),
      },
    )

    const patchText = await patchRes.text()
    if (!patchRes.ok) {
      return json(
        {
          error: 'failed to update Auth SMTP',
          status: patchRes.status,
          detail: patchText.slice(0, 500),
        },
        502,
      )
    }

    return json({
      ok: true,
      smtp_host: body.smtp_host,
      smtp_user: body.smtp_user,
      smtp_admin_email: body.smtp_admin_email,
      smtp_sender_name: body.smtp_sender_name,
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    return json({ error: message }, 500)
  }
})

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}
