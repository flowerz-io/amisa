/**
 * Recherche d’annonces eBay via l’API officielle Browse (item_summary/search).
 */
import { EBAY_MAX_PER_PAGE } from '../marketplace-limits.js';
import {
  availabilityToLogLine,
  ebayToProviderAvailability,
  type ProviderAvailabilityDTO,
} from '../provider-availability.js';
import { getAccessToken, getEbayApiBase } from './ebay-auth.js';

export type EbaySearchItem = {
  source: 'eBay';
  sourceKey: 'ebay';
  listingId?: string;
  sourceRank?: number;
  title: string;
  price?: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl: string;
  brand?: string;
  size?: string;
  condition?: string;
  publishedAtRelative?: string;
};

export type EbaySearchOptions = {
  page?: number;
  limit?: number;
};

export type EbaySearchStopReason =
  | 'ok'
  | 'api_error'
  | 'credentials_missing';

export type EbaySearchResult = {
  items: EbaySearchItem[];
  totalCount?: number;
  stopReason?: EbaySearchStopReason;
  /** Statut normalisé pour l’API client. */
  providerAvailability?: ProviderAvailabilityDTO;
};

/** Réponse minimale Browse API `search`. */
type EbayPrice = {
  value?: string;
  currency?: string;
};

type EbayImage = {
  imageUrl?: string;
};

type EbayItemSummary = {
  itemId?: string;
  title?: string;
  itemWebUrl?: string;
  image?: EbayImage;
  price?: EbayPrice;
  condition?: string;
  conditionId?: string;
};

type EbaySearchResponseJson = {
  total?: number;
  limit?: number;
  offset?: number;
  itemSummaries?: EbayItemSummary[];
  next?: string;
};

function clampLimit(requested?: number): number {
  const r = Math.floor(requested ?? EBAY_MAX_PER_PAGE);
  return Math.max(1, Math.min(EBAY_MAX_PER_PAGE, Number.isFinite(r) ? r : EBAY_MAX_PER_PAGE));
}

function parsePriceValue(raw: string | undefined): number | undefined {
  if (!raw) return undefined;
  const normalized = raw.replace(/\s/g, '').replace(',', '.');
  const n = parseFloat(normalized);
  return Number.isFinite(n) ? n : undefined;
}

function mapItemSummary(summary: EbayItemSummary, rank: number): EbaySearchItem | null {
  const itemId = summary.itemId?.trim();
  const title = summary.title?.trim();
  const listingUrl = summary.itemWebUrl?.trim();
  if (!itemId || !title || !listingUrl) return null;

  const priceNum = parsePriceValue(summary.price?.value);
  const currency = (summary.price?.currency ?? 'EUR').toUpperCase();
  const img = summary.image?.imageUrl?.trim();

  return {
    source: 'eBay',
    sourceKey: 'ebay',
    listingId: itemId,
    sourceRank: rank,
    title,
    price: priceNum ?? 0,
    currency,
    imageUrl: img,
    thumbnailUrl: img,
    listingUrl,
    condition: summary.condition ?? summary.conditionId ?? undefined,
  };
}

function finalizeResult(
  items: EbaySearchItem[],
  totalCount: number | undefined,
  stopReason: EbaySearchStopReason,
  logUrl: string
): EbaySearchResult {
  const availability = ebayToProviderAvailability(stopReason, items.length, totalCount);
  console.log('[EBAY_FINAL_URL]', logUrl);
  console.log(`[EBAY_STOP_REASON] ${stopReason}`);
  console.log(availabilityToLogLine('ebay', availability));
  return {
    items,
    totalCount,
    stopReason,
    providerAvailability: availability,
  };
}

/**
 * URL informative pour les logs (même base que l’appel réel : q, limit, offset).
 */
export function buildEbaySearchUrl(query: string, page: number = 1, limitHint?: number): string {
  const limit = clampLimit(limitHint ?? EBAY_MAX_PER_PAGE);
  const p = Math.max(1, Math.floor(page));
  const offset = (p - 1) * limit;
  const q = encodeURIComponent(query.trim());
  return `${getEbayApiBase()}/buy/browse/v1/item_summary/search?q=${q}&limit=${limit}&offset=${offset}`;
}

export async function searchEbayByText(
  query: string,
  options?: EbaySearchOptions
): Promise<EbaySearchResult> {
  const q = String(query ?? '').trim();
  const limit = clampLimit(options?.limit);
  const page = Math.max(1, Math.floor(options?.page ?? 1));
  const offset = (page - 1) * limit;

  const searchUrl = `${getEbayApiBase()}/buy/browse/v1/item_summary/search?q=${encodeURIComponent(q)}&limit=${limit}&offset=${offset}`;
  console.log('[EBAY_SEARCH_URL]', searchUrl);

  const token = await getAccessToken();
  if (!token) {
    console.error('[EBAY_API_ERROR] credentials_missing_or_token_failed');
    return finalizeResult([], undefined, 'credentials_missing', searchUrl);
  }

  const marketplaceId = (process.env.EBAY_MARKETPLACE_ID ?? 'EBAY_FR').trim() || 'EBAY_FR';

  try {
    const res = await fetch(searchUrl, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        'X-EBAY-C-MARKETPLACE-ID': marketplaceId,
        Accept: 'application/json',
      },
    });

    const text = await res.text();
    if (!res.ok) {
      console.error('[EBAY_API_ERROR] search_failed', res.status, text.slice(0, 800));
      const availability = ebayToProviderAvailability('api_error', 0, undefined);
      console.log('[EBAY_FINAL_URL]', searchUrl);
      console.log('[EBAY_STOP_REASON] api_error');
      console.log(availabilityToLogLine('ebay', availability));
      return {
        items: [],
        totalCount: undefined,
        stopReason: 'api_error',
        providerAvailability: availability,
      };
    }

    let data: EbaySearchResponseJson;
    try {
      data = JSON.parse(text) as EbaySearchResponseJson;
    } catch {
      console.error('[EBAY_API_ERROR] invalid_json', text.slice(0, 400));
      const availability = ebayToProviderAvailability('api_error', 0, undefined);
      console.log('[EBAY_FINAL_URL]', searchUrl);
      console.log('[EBAY_STOP_REASON] api_error');
      console.log(availabilityToLogLine('ebay', availability));
      return {
        items: [],
        totalCount: undefined,
        stopReason: 'api_error',
        providerAvailability: availability,
      };
    }

    const summaries = data.itemSummaries ?? [];
    const items: EbaySearchItem[] = [];
    let rank = 0;
    for (const s of summaries) {
      const mapped = mapItemSummary(s, rank);
      if (mapped) {
        items.push(mapped);
        rank += 1;
      }
    }

    const totalCount = typeof data.total === 'number' && data.total >= 0 ? data.total : undefined;
    return finalizeResult(items, totalCount, 'ok', searchUrl);
  } catch (err) {
    console.error('[EBAY_API_ERROR] search_exception', err);
    const availability = ebayToProviderAvailability('api_error', 0, undefined);
    console.log('[EBAY_FINAL_URL]', searchUrl);
    console.log('[EBAY_STOP_REASON] api_error');
    console.log(availabilityToLogLine('ebay', availability));
    return {
      items: [],
      totalCount: undefined,
      stopReason: 'api_error',
      providerAvailability: availability,
    };
  }
}
