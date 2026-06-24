# Admin console — deploy & local dev

The web client is the **admin console** for Stairs & Paths. It is a Vite/React app plus
**Pages Functions** (`functions/api/admin/*`) that serve the admin API from the same
origin, bound to the same D1 + R2 as the public Worker. The whole site is meant to sit
behind a **Cloudflare Access** application.

## Environment

- `VITE_API_BASE` (build-time): base URL of the public Worker for reading approved data and
  photo bytes. Defaults to the production Worker if unset. Set in `.env`/`.env.local` for
  local builds, or as a Pages build env var.

Admin writes go to relative `/api/admin/*` (same origin) — no base URL needed.

## Build

```bash
npm install
npm run build      # tsc -b && vite build → dist/
npm run lint
```

## Deploy to Cloudflare Pages

Bindings come from `wrangler.jsonc` (D1 `DB`, R2 `BUCKET`).

```bash
npx wrangler pages deploy dist
```

Then set the Access verification vars on the Pages project (so the functions can verify the
Access JWT as defense-in-depth):

```bash
npx wrangler pages secret put ACCESS_TEAM_DOMAIN   # e.g. myteam.cloudflareaccess.com
npx wrangler pages secret put ACCESS_AUD           # the Access application's Audience tag
```

## Protect with Cloudflare Access (one time, dashboard)

Zero Trust → Access → Applications → add a **self-hosted** app for the Pages hostname
(`<project>.pages.dev`), policy = allow your admin emails. Copy its **Audience (AUD) tag**
into `ACCESS_AUD` above.

## Local full-stack dev

Plain `vite dev` serves the UI but not the admin functions. To exercise the admin API
locally, run Pages dev with the auth check bypassed and a local D1:

```bash
npm run build
npx wrangler d1 execute stairs_paths_db --local --file=../cloudflare-backend/schema.sql
npx wrangler pages dev --binding DEV_BYPASS_AUTH=1
```

`DEV_BYPASS_AUTH=1` skips Access verification — **never set it in production.**
