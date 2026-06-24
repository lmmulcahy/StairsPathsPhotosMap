// Admin API for the review console. Served as a Cloudflare Pages Function on the same
// origin as the (Access-protected) admin site, bound to the same D1 + R2 as the public
// Worker. Every request is verified against Cloudflare Access (see _lib/access.ts).

import { verifyAccessJWT, type AccessIdentity } from './_lib/access';

interface Env {
  DB: D1Database;
  BUCKET: R2Bucket;
  ACCESS_TEAM_DOMAIN?: string;
  ACCESS_AUD?: string;
  DEV_BYPASS_AUTH?: string;
}

type Ctx = {
  request: Request;
  env: Env;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

async function authorize(env: Env, request: Request): Promise<AccessIdentity | Response> {
  // Local development convenience: `DEV_BYPASS_AUTH=1` skips Access verification.
  if (env.DEV_BYPASS_AUTH === '1') return { email: 'dev@local' };

  const token = request.headers.get('Cf-Access-Jwt-Assertion');
  if (!token || !env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) {
    return json({ error: 'Unauthorized' }, 401);
  }
  try {
    return await verifyAccessJWT(token, env.ACCESS_TEAM_DOMAIN, env.ACCESS_AUD);
  } catch {
    return json({ error: 'Unauthorized' }, 401);
  }
}

function pathDataToText(pathData: unknown): string | null {
  return pathData ? JSON.stringify(pathData) : null;
}

interface PathBody {
  name: string;
  startLatitude: number;
  startLongitude: number;
  endLatitude: number;
  endLongitude: number;
  pathData?: unknown;
}

export const onRequest = async (context: Ctx): Promise<Response> => {
  const { request, env } = context;
  const identity = await authorize(env, request);
  if (identity instanceof Response) return identity;

  const url = new URL(request.url);
  // Everything after /api/admin/
  const path = url.pathname.replace(/^\/api\/admin\/?/, '');
  const method = request.method;

  try {
    // GET /queue — pending path submissions and pending photos awaiting review.
    if (path === 'queue' && method === 'GET') {
      const submissions = await env.DB
        .prepare("SELECT * FROM submissions WHERE status = 'pending' ORDER BY created_at DESC")
        .all();
      const photos = await env.DB
        .prepare("SELECT p.*, s.name AS stairpath_name FROM photos p LEFT JOIN stairpaths s ON s.id = p.stairpath_id WHERE p.status = 'pending'")
        .all();
      return json({ submissions: submissions.results, photos: photos.results });
    }

    // POST /submissions/:id/approve | /reject
    const subMatch = path.match(/^submissions\/(\d+)\/(approve|reject)$/);
    if (subMatch && method === 'POST') {
      const [, id, action] = subMatch;
      const submission = await env.DB.prepare("SELECT * FROM submissions WHERE id = ? AND status = 'pending'").bind(id).first();
      if (!submission) return json({ error: 'Submission not found' }, 404);

      if (action === 'reject') {
        await env.DB.prepare("UPDATE submissions SET status = 'rejected', reviewed_at = datetime('now') WHERE id = ?").bind(id).run();
        return json({ id: Number(id), status: 'rejected' });
      }

      const payload = JSON.parse(submission.payload as string) as {
        name: string;
        startLatitude: number;
        startLongitude: number;
        endLatitude: number;
        endLongitude: number;
        pathData?: unknown;
      };
      const pd = pathDataToText(payload.pathData);

      if (submission.kind === 'create') {
        await env.DB.prepare(
          `INSERT INTO stairpaths (name, startLatitude, startLongitude, endLatitude, endLongitude, pathData)
           VALUES (?, ?, ?, ?, ?, ?)`
        ).bind(payload.name, payload.startLatitude, payload.startLongitude, payload.endLatitude, payload.endLongitude, pd).run();
      } else {
        await env.DB.prepare(
          `UPDATE stairpaths SET name = ?, startLatitude = ?, startLongitude = ?, endLatitude = ?, endLongitude = ?, pathData = ?
           WHERE id = ?`
        ).bind(payload.name, payload.startLatitude, payload.startLongitude, payload.endLatitude, payload.endLongitude, pd, submission.target_id).run();
      }

      await env.DB.prepare("UPDATE submissions SET status = 'approved', reviewed_at = datetime('now') WHERE id = ?").bind(id).run();
      return json({ id: Number(id), status: 'approved' });
    }

    // POST /photos/:id/approve | /reject
    const photoMatch = path.match(/^photos\/([^/]+)\/(approve|reject)$/);
    if (photoMatch && method === 'POST') {
      const [, id, action] = photoMatch;
      const photo = await env.DB.prepare('SELECT * FROM photos WHERE id = ?').bind(id).first();
      if (!photo) return json({ error: 'Photo not found' }, 404);

      if (action === 'approve') {
        await env.DB.prepare("UPDATE photos SET status = 'approved' WHERE id = ?").bind(id).run();
        return json({ id, status: 'approved' });
      }
      // Reject: remove the object and the row entirely.
      await env.BUCKET.delete(photo.object_key as string);
      await env.DB.prepare('DELETE FROM photos WHERE id = ?').bind(id).run();
      return json({ id, status: 'rejected' });
    }

    // POST /stairpaths — direct create (skips the queue; goes live).
    if (path === 'stairpaths' && method === 'POST') {
      const data = (await request.json()) as PathBody;
      const result = await env.DB.prepare(
        `INSERT INTO stairpaths (name, startLatitude, startLongitude, endLatitude, endLongitude, pathData)
         VALUES (?, ?, ?, ?, ?, ?) RETURNING *`
      ).bind(data.name, data.startLatitude, data.startLongitude, data.endLatitude, data.endLongitude, pathDataToText(data.pathData)).first();
      return json(result, 201);
    }

    // POST /stairpaths/:id/photos — direct admin upload (goes live, JPEG body).
    const adminPhotoMatch = path.match(/^stairpaths\/(\d+)\/photos$/);
    if (adminPhotoMatch && method === 'POST') {
      const stairpathId = adminPhotoMatch[1];
      const photoId = crypto.randomUUID();
      const objectKey = `photos/${stairpathId}/${photoId}.jpg`;
      await env.BUCKET.put(objectKey, request.body);
      await env.DB.prepare(
        `INSERT INTO photos (id, stairpath_id, object_key, status) VALUES (?, ?, ?, 'approved')`
      ).bind(photoId, stairpathId, objectKey).run();
      return json({ id: photoId, status: 'approved' }, 201);
    }

    // PUT/DELETE /stairpaths/:id — direct edit/delete (skips the queue).
    const spMatch = path.match(/^stairpaths\/(\d+)$/);
    if (spMatch) {
      const id = spMatch[1];
      if (method === 'PUT') {
        const data = (await request.json()) as PathBody;
        const result = await env.DB.prepare(
          `UPDATE stairpaths SET name = ?, startLatitude = ?, startLongitude = ?, endLatitude = ?, endLongitude = ?, pathData = ?
           WHERE id = ? RETURNING *`
        ).bind(data.name, data.startLatitude, data.startLongitude, data.endLatitude, data.endLongitude, pathDataToText(data.pathData), id).first();
        if (!result) return json({ error: 'Not found' }, 404);
        return json(result);
      }
      if (method === 'DELETE') {
        // Remove the path's photo objects + rows, then the path.
        const { results } = await env.DB.prepare('SELECT object_key FROM photos WHERE stairpath_id = ?').bind(id).all();
        await Promise.all((results as Array<{ object_key: string }>).map((r) => env.BUCKET.delete(r.object_key)));
        await env.DB.prepare('DELETE FROM photos WHERE stairpath_id = ?').bind(id).run();
        await env.DB.prepare('DELETE FROM stairpaths WHERE id = ?').bind(id).run();
        return json({ id: Number(id), deleted: true });
      }
    }

    return json({ error: 'Not found' }, 404);
  } catch (e) {
    console.error('Admin API error:', e instanceof Error ? e.message : e);
    return json({ error: 'Something went wrong.' }, 500);
  }
};
