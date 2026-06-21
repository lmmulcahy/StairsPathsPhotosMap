export interface Env {
	DB: D1Database;
}

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		const url = new URL(request.url);

		if (url.pathname === '/stairpaths') {
			if (request.method === 'GET') {
				const { results } = await env.DB.prepare('SELECT * FROM stairpaths').all();
				return new Response(JSON.stringify(results), {
					headers: { 'Content-Type': 'application/json' },
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
						headers: { 'Content-Type': 'application/json' },
					});
				} catch (e: any) {
					return new Response(JSON.stringify({ error: e.message }), { status: 400 });
				}
			}
		}

		return new Response('Not found', { status: 404 });
	},
};
