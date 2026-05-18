import {
  getEbayApiRoot,
  resolveEbayBrowseMarketplaceId,
  hasEbayOAuthCredentials,
} from '../../lib/ebay-env.js';
import { getEbayApplicationAccessToken } from './ebay-oauth-token.js';
import type { MarketplaceListingDTO } from '../../types.js';

export class EbayRateLimitedError extends Error {
  readonly isRateLimited = true;
  constructor(message: string) {
    super(message);
    this.name = 'EbayRateLimitedError';
  }
}

export class EbayProviderError extends Error {
  constructor(
    message: string,
    public readonly httpStatus: number,
    public readonly rawBody: string
  ) {
    super(message);
    this.name = 'EbayProviderError';
  }
}

function looksLikeRateLimit(status: number, body: string): boolean {
  if (status === 429) return true;
  const b = body.toLowerCase();
  return (
    status === 503 &&
    (b.includes('rate') || b.includes('limit') || b.includes('10001'))
  );
}

/**
 * eBay Buy Browse API — item_summary search (OAuth application token).
 */
export async function fetchEbayBrowseListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  if (!hasEbayOAuthCredentials()) {
    throw new Error(
      'ebay: missing EBAY_CLIENT_ID or EBAY_CLIENT_SECRET (Browse API OAuth)'
    );
  }

  const token = await getEbayApplicationAccessToken();

  const apiRoot = getEbayApiRoot();
  const marketplaceId = resolveEbayBrowseMarketplaceId();
  const limit = 30;

  const params = new URLSearchParams({
    q: searchText,
    limit: String(limit),
  });

  const url = `${apiRoot}/buy/browse/v1/item_summary/search?${params.toString()}`;

  console.log('[EBAY_SEARCH_QUERY]', { q: searchText, marketplaceId, limit });

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-EBAY-C-MARKETPLACE-ID': marketplaceId,
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
  });

  const rawText = await res.text();
  console.log('[EBAY_RESPONSE_STATUS]', res.status);

  if (!res.ok) {
    console.log('[EBAY_RESPONSE_ERROR]', {
      status: res.status,
      bodyPreview: rawText.slice(0, 800),
    });
    if (looksLikeRateLimit(res.status, rawText)) {
      throw new EbayRateLimitedError(
        `ebay Browse API HTTP ${res.status} rate_limited\n${rawText}`
      );
    }
    throw new EbayProviderError(
      `ebay Browse API HTTP ${res.status}\n${rawText}`,
      res.status,
      rawText
    );
  }

  let data: unknown;
  try {
    data = JSON.parse(rawText);
  } catch {
    console.log('[EBAY_RESPONSE_ERROR]', { reason: 'invalid_json', rawPreview: rawText.slice(0, 500) });
    throw new EbayProviderError(
      `ebay Browse API: response is not valid JSON\n${rawText}`,
      res.status,
      rawText
    );
  }

  const root = data as Record<string, unknown>;
  const errors = root.errors;
  if (Array.isArray(errors) && errors.length > 0) {
    console.log('[EBAY_RESPONSE_ERROR]', { errors });
    throw new EbayProviderError(
      `ebay Browse API errors: ${JSON.stringify(errors)}\n${rawText}`,
      res.status,
      rawText
    );
  }

  const summaries = root.itemSummaries;
  if (summaries !== undefined && !Array.isArray(summaries)) {
    console.log('[EBAY_RESPONSE_ERROR]', { reason: 'itemSummaries_not_array' });
    throw new EbayProviderError(
      `ebay Browse API: itemSummaries is not an array\n${rawText}`,
      res.status,
      rawText
    );
  }

  const items = Array.isArray(summaries) ? summaries : [];
  console.log('[EBAY_RESPONSE_COUNT]', items.length);

  const out: MarketplaceListingDTO[] = [];

  for (const raw of items) {
    if (!raw || typeof raw !== 'object') continue;
    const row = raw as Record<string, unknown>;
    const itemId = typeof row.itemId === 'string' ? row.itemId : '';
    if (!itemId) continue;

    const title =
      typeof row.title === 'string' ? row.title : `eBay ${itemId}`;

    let price = 0;
    let currency = 'EUR';
    const priceObj = row.price;
    if (priceObj && typeof priceObj === 'object' && !Array.isArray(priceObj)) {
      const p = priceObj as Record<string, unknown>;
      const val = p.value;
      if (typeof val === 'string' || typeof val === 'number') {
        price = Number(val);
      }
      const cur = p.currency;
      if (typeof cur === 'string') currency = cur;
    }

    let imageUrl: string | undefined;
    const img = row.image;
    if (img && typeof img === 'object' && !Array.isArray(img)) {
      const iu = (img as Record<string, unknown>).imageUrl;
      if (typeof iu === 'string') imageUrl = iu;
    }

    let listingUrl = `https://www.ebay.fr/itm/${encodeURIComponent(itemId)}`;
    if (typeof row.itemWebUrl === 'string') {
      listingUrl = row.itemWebUrl;
    } else if (typeof row.itemHref === 'string') {
      listingUrl = row.itemHref;
    }

    out.push({
      id: itemId,
      source: 'eBay',
      title,
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl,
      thumbnailUrl: imageUrl,
      listingUrl,
    });
  }

  return out;
}

/** @deprecated alias — ancien nom Finding API */
export const fetchEbayFindingListings = fetchEbayBrowseListings;

export type EbayDebugSearchPayload = {
  query: string;
  marketplaceId: string;
  apiRoot: string;
  oauthCredentialsPresent: boolean;
  tokenSuccess: boolean;
  tokenError?: string;
  searchStatus?: number;
  rawResponse?: string;
  itemCount: number;
  firstTitles: string[];
  searchError?: string;
};

/**
 * Appel diagnostic (route GET /debug-ebay) — ne remplace pas fetchEbayBrowseListings pour le pipeline.
 */
export async function runEbayDebugSearch(
  searchText: string
): Promise<EbayDebugSearchPayload> {
  const marketplaceId = resolveEbayBrowseMarketplaceId();
  const apiRoot = getEbayApiRoot();
  const oauthCredentialsPresent = hasEbayOAuthCredentials();

  const base: EbayDebugSearchPayload = {
    query: searchText,
    marketplaceId,
    apiRoot,
    oauthCredentialsPresent,
    tokenSuccess: false,
    itemCount: 0,
    firstTitles: [],
  };

  if (!oauthCredentialsPresent) {
    base.tokenError = 'missing EBAY_CLIENT_ID or EBAY_CLIENT_SECRET';
    return base;
  }

  let token: string;
  try {
    token = await getEbayApplicationAccessToken();
    base.tokenSuccess = true;
  } catch (e) {
    base.tokenError = e instanceof Error ? e.message : String(e);
    return base;
  }

  const limit = 30;
  const params = new URLSearchParams({
    q: searchText,
    limit: String(limit),
  });
  const url = `${apiRoot}/buy/browse/v1/item_summary/search?${params.toString()}`;

  console.log('[EBAY_SEARCH_QUERY]', { q: searchText, marketplaceId, limit });

  const res = await fetch(url, {
    headers: {
      Authorization: `Bearer ${token}`,
      'X-EBAY-C-MARKETPLACE-ID': marketplaceId,
      Accept: 'application/json',
    },
  });

  const rawText = await res.text();
  base.searchStatus = res.status;
  base.rawResponse = rawText;

  console.log('[EBAY_RESPONSE_STATUS]', res.status);

  if (!res.ok) {
    console.log('[EBAY_RESPONSE_ERROR]', {
      status: res.status,
      bodyPreview: rawText.slice(0, 800),
    });
    base.searchError = `ebay Browse API HTTP ${res.status}`;
    return base;
  }

  try {
    const data = JSON.parse(rawText) as Record<string, unknown>;
    const summaries = data.itemSummaries;
    const items = Array.isArray(summaries) ? summaries : [];
    base.itemCount = items.length;
    base.firstTitles = items.slice(0, 10).map((raw) => {
      if (!raw || typeof raw !== 'object') return '(no title)';
      const t = (raw as Record<string, unknown>).title;
      return typeof t === 'string' ? t : '(no title)';
    });
    console.log('[EBAY_RESPONSE_COUNT]', base.itemCount);
  } catch {
    console.log('[EBAY_RESPONSE_ERROR]', { reason: 'invalid_json', rawPreview: rawText.slice(0, 500) });
    base.searchError = 'response is not valid JSON';
  }

  return base;
}
