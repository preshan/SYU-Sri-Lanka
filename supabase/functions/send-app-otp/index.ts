// Reads Gmail SMTP from app_mail_settings, issues OTP, sends email.
// TEMPORARY companion to client-triggered auth mail (works on Flutter web + mobile).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.1'
import nodemailer from 'npm:nodemailer@6.9.16'

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: cors })
  }

  try {
    const { email, purpose } = await req.json()
    const to = String(email || '').trim().toLowerCase()
    const kind = String(purpose || 'signup').trim().toLowerCase()
    if (!to || !to.includes('@')) {
      return json({ error: 'email required' }, 400)
    }
    if (kind !== 'signup' && kind !== 'recovery') {
      return json({ error: 'invalid purpose' }, 400)
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const admin = createClient(supabaseUrl, serviceKey)

    const { data: code, error: otpErr } = await admin.rpc('issue_app_email_otp', {
      p_email: to,
      p_purpose: kind,
    })
    if (otpErr) {
      return json({ error: otpErr.message }, 429)
    }
    const token = String(code || '').trim()
    if (token.length !== 6) {
      return json({ error: 'could not create code' }, 500)
    }

    const { data: rows, error: smtpErr } = await admin.rpc(
      'get_mail_settings_internal',
    )
    if (smtpErr) throw smtpErr
    const row = Array.isArray(rows) ? rows[0] : rows
    if (!row?.smtp_user || !row?.smtp_pass) {
      return json({ error: 'SMTP not configured in app_mail_settings' }, 500)
    }

    const fromEmail = (row.from_email || row.smtp_user).trim()
    const fromName = row.from_name || 'SYU Sri Lanka'
    const isRecovery = kind === 'recovery'
    const subject = isRecovery
      ? `${token} is your SYU password reset code`
      : `${token} is your SYU verification code`
    const text = isRecovery
      ? `Your SYU Sri Lanka password reset code is:\n\n${token}\n\nIt expires in 30 minutes. If you did not request this, ignore this email.`
      : `Your SYU Sri Lanka verification code is:\n\n${token}\n\nEnter this 6-digit code in the app to finish signing up. It expires in 30 minutes.`

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
      to,
      subject,
      text,
    })

    return json({ ok: true })
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
