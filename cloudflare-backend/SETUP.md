# Backend setup & operations

The backend is a single Cloudflare Worker (`src/index.ts`) over D1 (`stairs_paths_db`) and
R2 (`stairs-paths-photos`). It serves **approved/live** data and accepts **submissions**
that land in a review queue. Admin review/approval lives in the web console (a separate
Cloudflare Pages project behind Cloudflare Access — added in the web-client PR).

## Public API (this Worker, no auth)

| Method | Path | Purpose |
| --- | --- | --- |
| GET | `/stairpaths` | List live (approved) paths. |
| GET | `/stairpaths/:id/photos` | List **approved** photos for a path. |
| GET | `/photos/:id` | Serve a photo's bytes by opaque id. |
| POST | `/submissions` | Submit a new path (`kind:"create"`) or an edit (`kind:"edit"`, with `targetId`). Stored `pending`. |
| POST | `/stairpaths/:id/photos` | Upload a photo (JPEG body). Stored `pending`. |
| POST | `/stairpaths` | **Legacy** direct create. Retained until iOS moves to `/submissions`, then removed. |
| PUT | `/stairpaths/:id` | **Legacy** direct edit. Retained until the web console owns edits, then removed. |

`/submissions` and photo uploads expect `pathData` as a JSON **array** of `[lat,lng]`
pairs; the Worker stringifies it once for storage.

## Apply the review-queue migration

The Worker never runs `CREATE TABLE` (see `../CLAUDE.md`). Apply schema changes by hand:

```bash
cd cloudflare-backend

# Local (for `wrangler dev`)
npx wrangler d1 execute stairs_paths_db --local  --file=migrations/0001_review_queue.sql

# Production — review first, then apply
npx wrangler d1 execute stairs_paths_db --remote --file=migrations/0001_review_queue.sql
```

`schema.sql` mirrors the full resulting schema for reference.

## Deploy

```bash
npx wrangler deploy
```

## Local testing

```bash
npx wrangler d1 execute stairs_paths_db --local --file=schema.sql   # fresh local DB
npx wrangler dev
# then curl http://127.0.0.1:8787/stairpaths etc.
```

## Admin console & Cloudflare Access (next PR)

The admin review UI and admin API ship as a **Cloudflare Pages** project (the `web-client`)
with **Pages Functions** under `/api/admin/*`, bound to the same `DB` and `BUCKET`. The
whole Pages site is protected by a **Cloudflare Access** application, so admin requests
carry a verified Access JWT (`Cf-Access-Jwt-Assertion`) that the functions check.

Dashboard steps (owner action, one time):
1. Create the Pages project from `web-client` (or `wrangler pages deploy`).
2. Bind D1 `stairs_paths_db` (as `DB`) and R2 `stairs-paths-photos` (as `BUCKET`) to the
   Pages project.
3. Zero Trust → Access → Applications → add a **self-hosted** app for the Pages hostname
   (`*.pages.dev`), policy = allow your admin emails.
4. Set the app's **Audience (AUD) tag** and your team domain as Pages env vars
   (`ACCESS_AUD`, `ACCESS_TEAM_DOMAIN`) so the functions can verify the JWT.
