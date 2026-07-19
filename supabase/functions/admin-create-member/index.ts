// Admin provisions a member: create auth user, finalize profile, email temp password.

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
      return json({ error: 'Only staff admins can add members' }, 403)
    }

    const body = await req.json()
    const email = String(body.email || '').trim().toLowerCase()
    const fullName = String(body.full_name || '').trim()
    const phone = String(body.phone || '').trim()
    if (!email.includes('@') || fullName.length < 2 || phone.length < 9) {
      return json(
        { error: 'Name, email, and phone are required' },
        400,
      )
    }

    const password = tempPassword(10)
    const admin = createClient(supabaseUrl, serviceKey)

    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: fullName, admin_provisioned: true },
    })
    if (createErr || !created.user) {
      return json({ error: createErr?.message || 'Could not create user' }, 400)
    }
    const userId = created.user.id

    const { data: profile, error: finErr } = await caller.rpc(
      'admin_finalize_provisioned_member',
      {
        p_user_id: userId,
        p_full_name: fullName,
        p_phone: phone,
        p_email: email,
        p_nic: body.nic ?? null,
        p_date_of_birth: body.date_of_birth ?? null,
        p_gender: body.gender ?? null,
        p_district_id: body.district_id ?? null,
        p_ds_division_id: body.ds_division_id ?? null,
        p_gn_division_id: body.gn_division_id ?? null,
        p_qualification_ids: body.qualification_ids ?? null,
        p_requested_youth_club_name: body.requested_youth_club_name ?? null,
        p_speaks_sinhala: body.speaks_sinhala ?? false,
        p_speaks_tamil: body.speaks_tamil ?? false,
        p_speaks_english: body.speaks_english ?? false,
        p_other_qualification: body.other_qualification ?? null,
        p_occupation: body.occupation ?? null,
        p_youth_club_registration_no: body.youth_club_registration_no ?? null,
      },
    )
    if (finErr) {
      // Roll back auth user if profile finalize fails.
      await admin.auth.admin.deleteUser(userId)
      return json({ error: finErr.message }, 400)
    }

    // Welcome email with temporary password.
    try {
      const { data: rows, error: smtpErr } = await admin.rpc(
        'get_mail_settings_internal',
      )
      if (smtpErr) throw smtpErr
      const row = Array.isArray(rows) ? rows[0] : rows
      if (row?.smtp_user && row?.smtp_pass) {
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
          subject: 'Your SYU Sri Lanka account',
          text:
            `Hello ${fullName},\n\n` +
            `An SYU admin created your membership account.\n\n` +
            `Email: ${email}\n` +
            `Temporary password: ${password}\n\n` +
            `Sign in with this password, then you will be asked to set a new password immediately.\n\n` +
            `— SYU Sri Lanka`,
        })
      }
    } catch (mailErr) {
      // Account exists; report mail failure separately (never return temp password).
      return json({
        ok: true,
        user_id: userId,
        email,
        profile,
        mail_error:
          mailErr instanceof Error ? mailErr.message : String(mailErr),
      })
    }

    return json({
      ok: true,
      user_id: userId,
      email,
      profile,
    })
  } catch (e) {
    const message = e instanceof Error ? e.message : String(e)
    return json({ error: message }, 500)
  }
})
