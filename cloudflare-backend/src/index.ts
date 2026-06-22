export interface Env {
	DB: D1Database;
	BUCKET: R2Bucket;
}

const corsHeaders = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders });
		}

		const url = new URL(request.url);

		if (url.pathname === '/stairpaths') {
			if (request.method === 'GET') {
				const { results } = await env.DB.prepare('SELECT * FROM stairpaths').all();
				return new Response(JSON.stringify(results), {
					headers: { 'Content-Type': 'application/json', ...corsHeaders },
				});
			}

			if (request.method === 'POST') {
				try {
					const data = await request.json() as any;
					const result = await env.DB.prepare(
						`INSERT INTO stairpaths (name, startLatitude, startLongitude, endLatitude, endLongitude) 
						 VALUES (?, ?, ?, ?, ?) RETURNING *`
					).bind(
						data.name, 
						data.startLatitude, 
						data.startLongitude, 
						data.endLatitude, 
						data.endLongitude
					).first();
					
					return new Response(JSON.stringify(result), {
						status: 201,
						headers: { 'Content-Type': 'application/json', ...corsHeaders },
					});
				} catch (e: any) {
					return new Response(JSON.stringify({ error: e.message }), { status: 400, headers: corsHeaders });
				}
			}
		}

		// GET /stairpaths/:id/photos
		const stairpathsPhotosMatch = url.pathname.match(/^\/stairpaths\/(\d+)\/photos$/);
		if (stairpathsPhotosMatch) {
			const stairpathId = stairpathsPhotosMatch[1];
			if (request.method === 'GET') {
				const { results } = await env.DB.prepare('SELECT * FROM photos WHERE stairpath_id = ?').bind(stairpathId).all();
				return new Response(JSON.stringify(results), {
					headers: { 'Content-Type': 'application/json', ...corsHeaders },
				});
			}

			if (request.method === 'POST') {
				try {
					const photoId = crypto.randomUUID();
					const objectKey = `photos/${stairpathId}/${photoId}.jpg`;
					
					await env.BUCKET.put(objectKey, request.body);
					
					await env.DB.prepare(
						`INSERT INTO photos (id, stairpath_id, object_key) VALUES (?, ?, ?)`
					).bind(photoId, stairpathId, objectKey).run();
					
					return new Response(JSON.stringify({ id: photoId }), {
						status: 201,
						headers: { 'Content-Type': 'application/json', ...corsHeaders },
					});
				} catch (e: any) {
					return new Response(JSON.stringify({ error: e.message }), { status: 500, headers: corsHeaders });
				}
			}
		}

		// GET /photos/:id
		const photoMatch = url.pathname.match(/^\/photos\/(.+)$/);
		if (photoMatch) {
			const photoId = photoMatch[1];
			if (request.method === 'GET') {
				const photoRecord = await env.DB.prepare('SELECT object_key FROM photos WHERE id = ?').bind(photoId).first();
				if (!photoRecord) return new Response('Not found', { status: 404, headers: corsHeaders });
				
				const object = await env.BUCKET.get(photoRecord.object_key as string);
				if (!object) return new Response('Not found', { status: 404, headers: corsHeaders });
				
				const headers = new Headers(corsHeaders);
				object.writeHttpMetadata(headers);
				headers.set('etag', object.httpEtag);
				headers.set('Content-Type', 'image/jpeg');
				
				return new Response(object.body, { headers });
			}
		}

		return new Response('Not found', { status: 404, headers: corsHeaders });
	},
};
