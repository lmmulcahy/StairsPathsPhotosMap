export interface Env {
	DB: D1Database;
	BUCKET: R2Bucket;
}

const corsHeaders = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, PUT, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type',
};

function json(body: unknown, status = 200): Response {
	return new Response(JSON.stringify(body), {
		status,
		headers: { 'Content-Type': 'application/json', ...corsHeaders },
	});
}

/** A validated path payload shared by submissions and the legacy direct write. */
interface PathInput {
	name: string;
	startLatitude: number;
	startLongitude: number;
	endLatitude: number;
	endLongitude: number;
	pathData: unknown;
}

/** Validates an incoming path body, returning the cleaned values or an error string. */
function validatePath(data: any): { value: PathInput } | { error: string } {
	if (typeof data !== 'object' || data === null) return { error: 'Body must be a JSON object.' };
	const name = typeof data.name === 'string' ? data.name.trim() : '';
	if (name.length === 0) return { error: 'Name is required.' };

	const coords: Array<[string, number]> = [
		['startLatitude', data.startLatitude],
		['endLatitude', data.endLatitude],
		['startLongitude', data.startLongitude],
		['endLongitude', data.endLongitude],
	];
	for (const [field, raw] of coords) {
		if (typeof raw !== 'number' || !Number.isFinite(raw)) return { error: `${field} must be a number.` };
		const limit = field.includes('atitude') ? 90 : 180;
		if (Math.abs(raw) > limit) return { error: `${field} is out of range.` };
	}

	return {
		value: {
			name,
			startLatitude: data.startLatitude,
			startLongitude: data.startLongitude,
			endLatitude: data.endLatitude,
			endLongitude: data.endLongitude,
			// pathData is an optional array of [lat, lng] pairs; stored stringified.
			pathData: data.pathData ?? null,
		},
	};
}

function pathDataToText(pathData: unknown): string | null {
	return pathData ? JSON.stringify(pathData) : null;
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		const url = new URL(request.url);

		try {
			// --- Paths (approved/live data) ---
			if (url.pathname === '/stairpaths') {
				if (request.method === 'GET') {
					const { results } = await env.DB.prepare('SELECT * FROM stairpaths').all();
					return json(results);
				}

				// Legacy direct create. Retained so the current iOS app keeps working until
				// it is switched to POST /submissions; it will be locked down then.
				if (request.method === 'POST') {
					const parsed = validatePath(await request.json());
					if ('error' in parsed) return json({ error: parsed.error }, 400);
					const p = parsed.value;
					const result = await env.DB.prepare(
						`INSERT INTO stairpaths (name, startLatitude, startLongitude, endLatitude, endLongitude, pathData)
						 VALUES (?, ?, ?, ?, ?, ?) RETURNING *`
					).bind(p.name, p.startLatitude, p.startLongitude, p.endLatitude, p.endLongitude, pathDataToText(p.pathData)).first();
					return json(result, 201);
				}
			}

			// --- Submissions (public, go to the review queue) ---
			if (url.pathname === '/submissions' && request.method === 'POST') {
				const data: any = await request.json();
				const kind = data?.kind;
				if (kind !== 'create' && kind !== 'edit') {
					return json({ error: "kind must be 'create' or 'edit'." }, 400);
				}
				const parsed = validatePath(data);
				if ('error' in parsed) return json({ error: parsed.error }, 400);

				let targetId: number | null = null;
				if (kind === 'edit') {
					if (typeof data.targetId !== 'number') return json({ error: 'targetId is required for edits.' }, 400);
					targetId = data.targetId;
				}

				const submitter = typeof data.submitter === 'string' ? data.submitter.slice(0, 200) : null;
				const result = await env.DB.prepare(
					`INSERT INTO submissions (kind, target_id, payload, submitter, status)
					 VALUES (?, ?, ?, ?, 'pending') RETURNING id`
				).bind(kind, targetId, JSON.stringify(parsed.value), submitter).first();

				return json({ id: (result as any)?.id, status: 'pending' }, 201);
			}

			// PUT /stairpaths/:id — legacy direct edit (locked down once the web admin
			// console owns direct edits).
			const stairpathMatch = url.pathname.match(/^\/stairpaths\/(\d+)$/);
			if (stairpathMatch && request.method === 'PUT') {
				const parsed = validatePath(await request.json());
				if ('error' in parsed) return json({ error: parsed.error }, 400);
				const p = parsed.value;
				const result = await env.DB.prepare(
					`UPDATE stairpaths SET name = ?, startLatitude = ?, startLongitude = ?, endLatitude = ?, endLongitude = ?, pathData = ?
					 WHERE id = ? RETURNING *`
				).bind(p.name, p.startLatitude, p.startLongitude, p.endLatitude, p.endLongitude, pathDataToText(p.pathData), stairpathMatch[1]).first();
				if (!result) return json({ error: 'Not found' }, 404);
				return json(result);
			}

			// --- Photos ---
			const photosMatch = url.pathname.match(/^\/stairpaths\/(\d+)\/photos$/);
			if (photosMatch) {
				const stairpathId = photosMatch[1];
				if (request.method === 'GET') {
					// Only approved photos are visible publicly.
					const { results } = await env.DB
						.prepare("SELECT * FROM photos WHERE stairpath_id = ? AND status = 'approved'")
						.bind(stairpathId).all();
					return json(results);
				}

				// Public photo upload — goes to the review queue as a pending photo.
				if (request.method === 'POST') {
					const photoId = crypto.randomUUID();
					const objectKey = `photos/${stairpathId}/${photoId}.jpg`;
					await env.BUCKET.put(objectKey, request.body);
					await env.DB.prepare(
						`INSERT INTO photos (id, stairpath_id, object_key, status) VALUES (?, ?, ?, 'pending')`
					).bind(photoId, stairpathId, objectKey).run();
					return json({ id: photoId, status: 'pending' }, 201);
				}
			}

			// GET /photos/:id — serves the image bytes by opaque id.
			const photoMatch = url.pathname.match(/^\/photos\/(.+)$/);
			if (photoMatch && request.method === 'GET') {
				const photoRecord = await env.DB.prepare('SELECT object_key FROM photos WHERE id = ?').bind(photoMatch[1]).first();
				if (!photoRecord) return new Response('Not found', { status: 404, headers: corsHeaders });

				const object = await env.BUCKET.get(photoRecord.object_key as string);
				if (!object) return new Response('Not found', { status: 404, headers: corsHeaders });

				const headers = new Headers(corsHeaders);
				object.writeHttpMetadata(headers);
				headers.set('etag', object.httpEtag);
				headers.set('Content-Type', 'image/jpeg');
				return new Response(object.body, { headers });
			}

			return new Response('Not found', { status: 404, headers: corsHeaders });
		} catch (e: any) {
			// Log server-side; don't leak internals to clients.
			console.error('Request failed:', e?.message ?? e);
			return json({ error: 'Something went wrong.' }, 500);
		}
	},
};
