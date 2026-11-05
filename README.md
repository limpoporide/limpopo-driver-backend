# limpopo-driver-backend

NestJS API + Supabase (Postgres migrations) for the Limpopo driver app. Remote project ref: `hzvmtghpjaibmyvjhhzy`.

## Setup

Requires Docker (local Postgres) and Node.

```bash
npm install
npx supabase login
npx supabase link --project-ref hzvmtghpjaibmyvjhhzy
cp .env.example .env
```

## Postgres

Local Postgres runs in Docker with `npm run supabase:start` (DB at `postgresql://postgres:postgres@127.0.0.1:54322/postgres`).

| Task | Command |
| --- | --- |
| Pull remote schema into `supabase/migrations` | `npm run db:pull` |
| Create a migration | `npm run db:migration:new -- name` |
| Diff local changes into a migration | `npm run db:diff -- name` |
| Rebuild local DB from migrations | `npm run db:reset` |
| Apply migrations to remote | `npm run db:push` |

## API (NestJS)

The former Edge Functions are NestJS routes. Each is `POST /<function-name>` with the same request/response JSON as before
(errors are `{ "error": "..." }`).

```bash
npm run start:dev   # watch mode
npm run build && npm run start:prod
```

`GET /health` is available for liveness checks. SMS and account routes are limited to 10 requests/min per client IP (300/min elsewhere). Format with `npm run format`; CI runs `npm run format:check`. Deployment is described in the rider backend's `deploy/` folder; this repo's `.github/workflows/deploy.yml` redeploys only the `driver` service.

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are no longer injected; set them in `.env`.

## Note

`limpopo-rider-backend` targets the same remote project. Avoid conflicting migrations between the two repos, and do not run both local stacks at once (same ports).
