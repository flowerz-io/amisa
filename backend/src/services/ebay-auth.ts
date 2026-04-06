/**
 * OAuth2 client credentials pour l’API eBay (Browse, etc.).
 * Variables : EBAY_CLIENT_ID, EBAY_CLIENT_SECRET, EBAY_ENV (production | sandbox).
 */

let cached: { token: string; expiresAtMs: number } | null = null;

export function getEbayApiBase(): string {
  return process.env.EBAY_ENV === 'sandbox'
    ? 'https://api.sandbox.ebay.com'
    : 'https://api.ebay.com';
}

const DEFAULT_SCOPE = 'https://api.ebay.com/oauth/api_scope';

/**
 * Retourne un access token valide, ou null si identifiants absents ou échec token.
 * Cache en mémoire jusqu’à expiration (marge de sécurité avant expiry).
 */
export async function getAccessToken(): Promise<string | null> {
  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) {
    return null;
  }

  const now = Date.now();
  if (cached && cached.expiresAtMs > now + 5_000) {
    return cached.token;
  }

  const base = getEbayApiBase();
  const tokenUrl = `${base}/identity/v1/oauth2/token`;
  const scope = (process.env.EBAY_OAUTH_SCOPE ?? DEFAULT_SCOPE).trim();
  const body = `grant_type=client_credentials&scope=${encodeURIComponent(scope)}`;
  const basic = Buffer.from(`${clientId}:${clientSecret}`, 'utf8').toString('base64');

  try {
    const res = await fetch(tokenUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Authorization: `Basic ${basic}`,
      },
      body,
    });

    const text = await res.text();
    if (!res.ok) {
      console.error('[EBAY_API_ERROR] token_request_failed', res.status, text.slice(0, 500));
      return null;
    }

    const data = JSON.parse(text) as { access_token?: string; expires_in?: number };
    if (!data.access_token) {
      console.error('[EBAY_API_ERROR] token_response_missing_access_token');
      return null;
    }

    const expiresIn = typeof data.expires_in === 'number' && data.expires_in > 60 ? data.expires_in : 7200;
    const marginSec = 120;
    cached = {
      token: data.access_token,
      expiresAtMs: now + Math.max(30_000, (expiresIn - marginSec) * 1000),
    };
    return cached.token;
  } catch (err) {
    console.error('[EBAY_API_ERROR] token_request_exception', err);
    return null;
  }
}

/** Utile pour tests ou après rotation de secret. */
export function clearEbayTokenCache(): void {
  cached = null;
}
