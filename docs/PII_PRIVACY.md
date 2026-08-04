# PII & data privacy

Notes for operators — not a legal privacy policy.

## Data we store
- Auth email (Supabase Auth)
- Profile: name, phone, NIC, DOB, gender, location IDs, club, avatar path
- Qualifications, social links
- Activity logs (action metadata — no raw passwords)

## Access
- Members: own profile only (RLS)
- Staff (`division_admin` / `district_admin` / `super_admin`): operational access via admin tools (RLS helpers)

## Rules
- Never log NIC/passwords in client crash reports
- Prefer private storage buckets for avatars/chat media
- Retention: active membership duration + admin audit needs (confirm with SYU policy)
