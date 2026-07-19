// Admin changes provisioned member email: update email, reset temp password, email it.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import nodemailer from 'npm:nodemailer@6.9.16'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  })
}

function tempPassword(len = 10): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  const bytes = crypto.getRandomValues(new Uint8Array(len))
  let out = ''
  for (let i = 0; i < len; i++) out += alphabet[bytes[i] % alphabet.length]
  return out
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const authHeader = req.headers.get('Authorization') || ''

    const caller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const {
      data: { user: adminUser },
      error: userErr,
    } = await caller.auth.getUser()
    if (userErr || !adminUser) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const { data: staff, error: staffErr } = await caller.rpc('is_staff_admin')
    if (staffErr || staff !== true) {
      return json({ error: 'Only staff admins can change member email' }, 403)
    }

    const body = await req.json()
    const memberId = String(body.member_id || '').trim()
    const email = String(body.email || '').trim().toLowerCase()
    if (!memberId || !email.includes('@')) {
      return json({ error: 'Member id and valid email are required' }, 400)
    }

    const { data: updatedEmail, error: updErr } = await caller.rpc(
      'admin_update_provisioned_email',
      {
        p_member_id: memberId,
        p_new_email: email,
      },
    )
    if (updErr) {
      return json({ error: updErr.message }, 400)
    }

    const password = tempPassword(10)
    const admin = createClient(supabaseUrl, serviceKey)

    const { error: pwErr } = await admin.auth.admin.updateUserById(memberId, {
      email,
      password,
      email_confirm: true,
    })
    if (pwErr) {
      return json({ error: pwErr.message }, 400)
    }

    // Keep forced password-change gate active after reset.
    await admin
      .from('profiles')
      .update({ must_change_password: true, email })
      .eq('id', memberId)

    let fullName = String(body.full_name || '').trim()
    if (!fullName) {
      const { data: profile } = await admin
        .from('profiles')
        .select('full_name')
        .eq('id', memberId)
        .maybeSingle()
      fullName = (profile?.full_name as string | undefined)?.trim() || 'Member'
    }

    try {
      const { data: rows, error: smtpErr } = await admin.rpc(
        'get_mail_settings_internal',
      )
      if (smtpErr) throw smtpErr
      const row = Array.isArray(rows) ? rows[0] : rows
      if (!row?.smtp_user || !row?.smtp_pass) {
        throw new Error('Mail settings not configured')
      }
      const fromEmail = (row.from_email || row.smtp_user).trim()
      const fromName = row.from_name || 'SYU Sri Lanka'
      const port = Number(row.smtp_port || 465)
      const transporter = nodemailer.createTransport({
        host: row.smtp_host || 'smtp.gmail.com',
        port,
        secure: port === 465,
        auth: {
          user: row.smtp_user.trim(),
          pass: row.smtp_pass,
        },
      })
      await transporter.sendMail({
        from: `"${fromName}" <${fromEmail}>`,
        to: email,
        subject: 'Your updated SYU Sri Lanka login',
        text:
          `Hello ${fullName},\n\n` +
          `An SYU admin updated the email on your membership account.\n\n` +
          `Email: ${email}\n` +
          `Temporary password: ${password}\n\n` +
          `Sign in with this password, then you will be asked to set a new password immediately.\n\n` +
          `— SYU Sri Lanka`,
      })
    } catch (mailErr) {
      return json({
        ok: true,
        email: updatedEmail ?? email,
        mail_error:
          mailErr instanceof Error ? mailErr.message : String(mailErr),
      })
    }

    return json({
      ok: true,
      email: updatedEmail ?? email,
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    return json({ error: message }, 500)
  }
})
