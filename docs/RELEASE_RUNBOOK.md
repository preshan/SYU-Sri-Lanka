# Deployment & release runbook

## Branches

- `main` — tagged releases
- `develop` — integration branch for day-to-day work

## Ship a mobile build

1. Ensure `develop` is green (`flutter analyze`, `flutter test`).
2. Bump `version:` in `pubspec.yaml` (e.g. `0.2.0+2`).
3. Merge `develop` → `main` (PR preferred).
4. Tag: `git tag -a vX.Y.Z -m "vX.Y.Z"` and push tags.
5. Build APK:

```bash
flutter build apk --release
mkdir -p releases
cp build/app/outputs/flutter-apk/app-release.apk releases/SYU-Sri-Lanka-vX.Y.Z.apk
```

6. Create GitHub Release with the APK attached (`gh release create`).

## Apply DB migrations

Use Supabase Management API or CLI against the project ref. Migrations live in `supabase/migrations/` and are ordered by timestamp prefix. After DDL changes, run `notify pgrst, 'reload schema';` if REST returns missing-table errors.

## Admin web (local)

```bash
flutter run -d chrome --web-port=5280
# open /admin while signed in as super_admin
```

## Web (GitHub Pages)

Live URL: **https://preshan.github.io/SYU-Sri-Lanka/**

Deploy is automatic on push to `main` (workflow: `.github/workflows/deploy-github-pages.yml`), or run **Actions → Deploy GitHub Pages → Run workflow**.

### One-time setup

1. **Repo secrets** (`Settings → Secrets and variables → Actions`):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`  
   (same values as local `.env`)

2. **Enable Pages** (`Settings → Pages`):
   - Source: **GitHub Actions** (not “Deploy from a branch”)

3. **Supabase** (`Authentication → URL Configuration`):
   - Add redirect / site URL: `https://preshan.github.io/SYU-Sri-Lanka`
   - Optionally: `https://preshan.github.io/SYU-Sri-Lanka/**`

The web build uses `--base-href /SYU-Sri-Lanka/` and copies `index.html` to `404.html` for SPA deep links.

## Rollback

- App: redistribute previous APK / Play track rollback.
- DB: prefer forward-fix migrations; do not drop columns without a plan.
- Web: re-run a previous successful **Deploy GitHub Pages** workflow, or revert `main` and push.
