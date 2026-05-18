/**
 * Configuration eBay — Browse API (OAuth client_credentials + X-EBAY-C-MARKETPLACE-ID).
 */

const DEFAULT_BROWSE_MARKETPLACE = 'EBAY_FR';

/** Production ou sandbox selon EBAY_ENV. */
export function getEbayApiRoot(): string {
  const e = process.env.EBAY_ENV?.trim().toLowerCase();
  if (e === 'sandbox' || e === 'development') {
    return 'https://api.sandbox.ebay.com';
  }
  return 'https://api.ebay.com';
}

/**
 * En-tête Browse API : EBAY_FR, EBAY_US, …
 * Prend EBAY_MARKETPLACE_ID si défini, sinon EBAY_GLOBAL_ID legacy (EBAY-FR → EBAY_FR).
 */
export function resolveEbayBrowseMarketplaceId(): string {
  const raw =
    process.env.EBAY_MARKETPLACE_ID?.trim() ||
    process.env.EBAY_GLOBAL_ID?.trim() ||
    process.env.EBAY_GLOBAL_ID_V2?.trim() ||
    '';
  if (!raw) return DEFAULT_BROWSE_MARKETPLACE;

  let u = raw.toUpperCase();
  if (u.startsWith('EBAY-')) {
    u = u.replace(/^EBAY-/, 'EBAY_');
  }
  if (u.startsWith('EBAY_')) return u;
  return DEFAULT_BROWSE_MARKETPLACE;
}

export function hasEbayOAuthCredentials(): boolean {
  return Boolean(
    process.env.EBAY_CLIENT_ID?.trim() && process.env.EBAY_CLIENT_SECRET?.trim()
  );
}

export type EbayAppIdSource = 'EBAY_CLIENT_ID' | 'none';

export type EbayGlobalIdSource =
  | 'EBAY_MARKETPLACE_ID'
  | 'EBAY_GLOBAL_ID'
  | 'EBAY_GLOBAL_ID_V2'
  | 'default';

export function getEbayAppIdSource(): EbayAppIdSource {
  return process.env.EBAY_CLIENT_ID?.trim() ? 'EBAY_CLIENT_ID' : 'none';
}

export function getEbayGlobalIdSource(): EbayGlobalIdSource {
  if (process.env.EBAY_MARKETPLACE_ID?.trim()) return 'EBAY_MARKETPLACE_ID';
  if (process.env.EBAY_GLOBAL_ID?.trim()) return 'EBAY_GLOBAL_ID';
  if (process.env.EBAY_GLOBAL_ID_V2?.trim()) return 'EBAY_GLOBAL_ID_V2';
  return 'default';
}

export function logEbayFetchConfig(oauthReady: boolean): void {
  const mp = resolveEbayBrowseMarketplaceId();
  const env =
    process.env.EBAY_ENV?.trim() ||
    process.env.NODE_ENV?.trim() ||
    'development';
  console.log(
    `[EBAY_CONFIG] oauthReady=${oauthReady} marketplaceId=${mp} apiRoot=${getEbayApiRoot()} env=${env}`
  );
}

export function getEbayDebugSnapshot(): {
  appIdPresent: boolean;
  appIdSource: EbayAppIdSource;
  oauthSecretPresent: boolean;
  globalId: string;
  globalIdSource: EbayGlobalIdSource;
} {
  const cid = !!process.env.EBAY_CLIENT_ID?.trim();
  const sec = !!process.env.EBAY_CLIENT_SECRET?.trim();
  return {
    appIdPresent: cid && sec,
    appIdSource: getEbayAppIdSource(),
    oauthSecretPresent: sec,
    globalId: resolveEbayBrowseMarketplaceId(),
    globalIdSource: getEbayGlobalIdSource(),
  };
}
