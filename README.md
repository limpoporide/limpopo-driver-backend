# limpopo-driver-backend

Supabase backend (Postgres migrations + Edge Functions) for the Limpopo driver app. Remote project ref: `hzvmtghpjaibmyvjhhzy`.

## Setup

Requires Docker (local Postgres) and Node.

```bash
npm install
npx supabase login
npx supabase link --project-ref hzvmtghpjaibmyvjhhzy
cp .env.example .env
```

## Postgres

Local Postgres runs in Docker with `npm start` (DB at `postgresql://postgres:postgres@127.0.0.1:54322/postgres`).

| Task | Command |
| --- | --- |
| Pull remote schema into `supabase/migrations` | `npm run db:pull` |
| Create a migration | `npm run db:migration:new -- name` |
| Diff local changes into a migration | `npm run db:diff -- name` |
| Rebuild local DB from migrations | `npm run db:reset` |
| Apply migrations to remote | `npm run db:push` |

## Edge Functions

```bash
npm run functions:serve
npx supabase functions deploy <name>
```

## Note

`limpopo-rider-backend` targets the same remote project. Avoid conflicting migrations between the two repos, and do not run both local stacks at once (same ports).
