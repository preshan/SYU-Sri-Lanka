# PII & data privacy (draft)

## Data we store
- Auth email (Supabase Auth)
- Profile: name, phone, NIC, DOB, gender, location IDs, club, avatar path
- Qualifications, social links
- Activity logs (action metadata — no raw passwords)

## Access
- Members: own profile only (RLS)
- Admins (`super_admin` / `district_admin`): operational access via admin tools (enforced with RLS helpers)

## Rules
- Never log NIC/passwords in client crash reports
- Prefer private storage buckets for avatars/chat media
- Retention: active membership duration + admin audit needs (finalize with SYU policy)
