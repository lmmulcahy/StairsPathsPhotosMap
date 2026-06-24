// Verifies a Cloudflare Access JWT (the `Cf-Access-Jwt-Assertion` header) against the
// team's public keys. The Pages site is already gated by an Access application; this is
// defense-in-depth so the admin API can't be hit directly without a valid Access token.

export interface AccessIdentity {
  email?: string;
  sub?: string;
}

interface JWK {
  kid: string;
  kty: string;
  n: string;
  e: string;
  alg?: string;
}

let cachedKeys: { keys: JWK[]; fetchedAt: number } | null = null;
const CERTS_TTL_MS = 60 * 60 * 1000;

async function getKeys(teamDomain: string): Promise<JWK[]> {
  const now = Date.now();
  if (cachedKeys && now - cachedKeys.fetchedAt < CERTS_TTL_MS) return cachedKeys.keys;
  const res = await fetch(`https://${teamDomain}/cdn-cgi/access/certs`);
  if (!res.ok) throw new Error('Failed to fetch Access certs');
  const data = (await res.json()) as { keys: JWK[] };
  cachedKeys = { keys: data.keys, fetchedAt: now };
  return data.keys;
}

function b64urlToBytes(s: string): Uint8Array {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  const pad = s.length % 4;
  if (pad) s += '='.repeat(4 - pad);
  const bin = atob(s);
  const arr = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) arr[i] = bin.charCodeAt(i);
  return arr;
}

function b64urlToString(s: string): string {
  return new TextDecoder().decode(b64urlToBytes(s));
}

export async function verifyAccessJWT(token: string, teamDomain: string, aud: string): Promise<AccessIdentity> {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Malformed JWT');
  const [headerB64, payloadB64, sigB64] = parts;

  const header = JSON.parse(b64urlToString(headerB64)) as { kid: string; alg: string };
  if (header.alg !== 'RS256') throw new Error('Unexpected JWT alg');

  const jwk = (await getKeys(teamDomain)).find((k) => k.kid === header.kid);
  if (!jwk) throw new Error('Unknown signing key');

  const key = await crypto.subtle.importKey(
    'jwk',
    jwk as JsonWebKey,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify']
  );

  const verified = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5',
    key,
    b64urlToBytes(sigB64),
    new TextEncoder().encode(`${headerB64}.${payloadB64}`)
  );
  if (!verified) throw new Error('Invalid signature');

  const payload = JSON.parse(b64urlToString(payloadB64)) as {
    aud?: string | string[];
    exp?: number;
    email?: string;
    sub?: string;
  };

  if (!payload.exp || payload.exp < Math.floor(Date.now() / 1000)) throw new Error('Token expired');
  const auds = Array.isArray(payload.aud) ? payload.aud : [payload.aud];
  if (!auds.includes(aud)) throw new Error('Audience mismatch');

  return { email: payload.email, sub: payload.sub };
}
