# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project overview

**YogaFlow Manager** is a React + Vite + TypeScript SPA for yoga course management, backed by Supabase (PostgreSQL, Auth, RLS, Edge Functions). There is no separate backend server.

## Cursor Cloud specific instructions

### Services

| Service | Port | Command | Notes |
|---------|------|---------|-------|
| Vite dev server | 5173 | `npm run dev -- --host 0.0.0.0 --port 5173` | Frontend only; requires Supabase env vars |
| Supabase (remote) | — | — | No Docker in Cloud Agent VMs without elevated privileges; use a remote DEV Supabase project via `.env` |
| Supabase Edge Functions | — | `supabase functions deploy …` | Optional for email/password-reset flows |

### Environment variables

Create `.env` from `.env.example` with **DEV** Supabase credentials (see `origin/Julius` branch `docs/ENVIRONMENTS.md` for the full DEV/PROD policy):

- `VITE_SUPABASE_URL` — Supabase project URL
- `VITE_SUPABASE_ANON_KEY` — public anon key

`.env` is gitignored; never commit credentials. Prefer DEV project ref `mufxhtctutfpzklwqnze` for local work, not the production project.

### Common commands

```bash
npm install          # install dependencies
npm run dev          # start dev server (http://localhost:5173)
npm run build        # production build → dist/
npm run preview      # serve production build
npm run lint         # ESLint (see caveat below)
```

Optional (requires Supabase CLI login + linked DEV project on `Julius` branch):

```bash
npm run db:push      # apply migrations (only on branches that include this script)
```

### Lint caveat

`npm run lint` may fail with a `@typescript-eslint/no-unused-expressions` rule loading error (ESLint 9.x + typescript-eslint compatibility). `npm run build` succeeds and is the reliable compile check.

### Supabase local stack

`supabase start` requires Docker, which is not available in Cloud Agent VMs without root. Use a remote DEV Supabase project instead. Sample users and seed SQL are documented in `SAMPLE_DATA_SETUP.md`.

### Hello-world verification

1. `npm install && npm run dev`
2. Open http://localhost:5173
3. Log in (DEV test user from `SAMPLE_DATA_SETUP.md`, or a user you create on DEV)
4. Open **Kurse** in the sidebar and confirm course cards load

### Gotchas

- Without `VITE_SUPABASE_*` in `.env`, login shows a German “Supabase ist nicht konfiguriert” error (placeholder URL is blocked in `AuthContext`).
- Email verification, password reset, and admin user delete require deployed Edge Functions + SMTP secrets (see `EMAIL_SYSTEM_DOCUMENTATION.md`).
- The `main` branch has migrations under `supabase/migrations/` but no `supabase/config.toml`; the `Julius` branch has fuller workflow docs and CLI linking scripts.
