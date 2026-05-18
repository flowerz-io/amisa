/**
 * eBay OAuth 2.0 — application token (client_credentials).
 * @see https://developer.ebay.com/api-docs/static/oauth-client-credentials-grant.html
 */

import { getEbayApiRoot } from '../../lib/ebay-env.js';

const OAUTH_API_SCOPE = 'https://api.ebay.com/oauth/api_scope';

type CachedToken = {
  token: string;
  expiresAtMs: number;
};

let cache: CachedToken | null = null;

function getClientCredentials(): { clientId: string; clientSecret: string } {
  const clientId = process.env.EBAY_CLIENT_ID?.trim();
  const clientSecret = process.env.EBAY_CLIENT_SECRET?.trim();
  if (!clientId || !clientSecret) {
    throw new Error(
      'ebay_oauth: EBAY_CLIENT_ID and EBAY_CLIENT_SECRET are required for Browse API'
    );
  }
  return { clientId, clientSecret };
}

function basicAuthHeader(clientId: string, clientSecret: string): string {
  const raw = `${clientId}:${clientSecret}`;
  const b64 = Buffer.from(raw, 'utf8').toString('base64');
  return `Basic ${b64}`;
}

export async function getEbayApplicationAccessToken(): Promise<string> {
  const now = Date.now();
  if (cache && cache.expiresAtMs - 60_000 > now) {
    return cache.token;
  }

  const { clientId, clientSecret } = getClientCredentials();
  const root = getEbayApiRoot();
  const tokenUrl = `${root}/identity/v1/oauth2/token`;

  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    scope: OAUTH_API_SCOPE,
  });

  const res = await fetch(tokenUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      Authorization: basicAuthHeader(clientId, clientSecret),
    },
    body: body.toString(),
  });

  const rawText = await res.text();
  if (!res.ok) {
    console.log('[EBAY_RESPONSE_ERROR]', {
      step: 'oauth_token',
      status: res.status,
      bodyPreview: rawText.slice(0, 500),
    });
    throw new Error(
      `ebay_oauth: token request failed HTTP ${res.status}: ${rawText.slice(0, 1500)}`
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new Error(
      `ebay_oauth: invalid JSON from token endpoint: ${rawText.slice(0, 500)}`
    );
  }

  const obj = parsed as Record<string, unknown>;
  const accessToken = obj.access_token;
  const expiresIn = obj.expires_in;
  if (typeof accessToken !== 'string' || !accessToken.length) {
    throw new Error(
      `ebay_oauth: missing access_token in response: ${rawText.slice(0, 500)}`
    );
  }

  const ttlSec =
    typeof expiresIn === 'number'
      ? expiresIn
      : typeof expiresIn === 'string'
        ? parseInt(expiresIn, 10)
        : 7200;
  const safeTtl = Number.isFinite(ttlSec) ? ttlSec : 7200;

  cache = {
    token: accessToken,
    expiresAtMs: now + safeTtl * 1000,
  };

  console.log('[EBAY_TOKEN_OK]', {
    expiresInSec: safeTtl,
    cacheUntilMs: cache.expiresAtMs,
  });

  return accessToken;
}

/** Tests unitaires / redémarrage propre */
export function clearEbayTokenCacheForTests(): void {
  cache = null;
}
