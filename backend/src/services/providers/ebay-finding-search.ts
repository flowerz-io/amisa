import type { MarketplaceListingDTO } from '../../types.js';

function asArray<T>(x: T | T[] | undefined | null): T[] {
  if (x === undefined || x === null) return [];
  return Array.isArray(x) ? x : [x];
}

function firstStr(v: unknown): string | undefined {
  if (typeof v === 'string') return v;
  if (Array.isArray(v) && typeof v[0] === 'string') return v[0];
  return undefined;
}

function firstObj(v: unknown): Record<string, unknown> | undefined {
  const a = asArray(v);
  const x = a[0];
  return x && typeof x === 'object' && !Array.isArray(x)
    ? (x as Record<string, unknown>)
    : undefined;
}

/**
 * eBay Finding API (REST JSON) — nécessite EBAY_APP_ID (clé « App ID » développeur).
 * @see https://developer.ebay.com/DevZone/finding/Concepts/FindingAPIGuide.html
 */
export async function fetchEbayFindingListings(
  searchText: string
): Promise<MarketplaceListingDTO[]> {
  const appId = process.env.EBAY_APP_ID?.trim();
  if (!appId) {
    throw new Error(
      'ebay: EBAY_APP_ID is not set — add your eBay Application key (Finding API)'
    );
  }

  const globalId =
    process.env.EBAY_GLOBAL_ID?.trim() ||
    process.env.EBAY_GLOBAL_ID_V2?.trim() ||
    'EBAY-FR';

  const params = new URLSearchParams({
    'OPERATION-NAME': 'findItemsByKeywords',
    'SERVICE-VERSION': '1.13.0',
    'SECURITY-APPNAME': appId,
    'RESPONSE-DATA-FORMAT': 'JSON',
    'REST-PAYLOAD': '',
    keywords: searchText,
    'paginationInput.entriesPerPage': '30',
    'GLOBAL-ID': globalId,
  });

  const url = `https://svcs.ebay.com/services/search/FindingService/v1?${params.toString()}`;
  const res = await fetch(url, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'AmisaBackend/1.0 (+https://github.com)',
    },
  });

  const rawText = await res.text();
  if (!res.ok) {
    throw new Error(`ebay: HTTP ${res.status} ${rawText.slice(0, 200)}`);
  }

  let data: unknown;
  try {
    data = JSON.parse(rawText);
  } catch {
    throw new Error(`ebay: invalid JSON body ${rawText.slice(0, 200)}`);
  }

  const root = data as Record<string, unknown>;
  const fr = asArray(root.findItemsByKeywordsResponse)[0] as
    | Record<string, unknown>
    | undefined;
  if (!fr) {
    throw new Error('ebay: missing findItemsByKeywordsResponse');
  }

  const ack = firstStr(fr.ack);
  if (ack && ack !== 'Success' && ack !== 'Warning') {
    const msg = firstStr(fr.errorMessage) ?? JSON.stringify(fr.errorMessage);
    throw new Error(`ebay: API ack=${ack} ${msg ?? ''}`);
  }

  const searchResult = firstObj(fr.searchResult);
  if (!searchResult) return [];

  const itemsRaw = searchResult.item;
  const items: unknown[] = Array.isArray(itemsRaw)
    ? itemsRaw
    : itemsRaw !== undefined && itemsRaw !== null
      ? [itemsRaw]
      : [];
  const out: MarketplaceListingDTO[] = [];

  for (const rawItem of items) {
    if (!rawItem || typeof rawItem !== 'object') continue;
    const it = rawItem as Record<string, unknown>;
    const itemId = firstStr(it.itemId) ?? '';
    if (!itemId) continue;

    const title = firstStr(it.title) ?? 'eBay item';
    const gallery = firstStr(it.galleryURL) ?? firstStr(it.pictureURLSuperSize);
    const listingUrl =
      firstStr(it.viewItemURL) ?? `https://www.ebay.fr/itm/${itemId}`;

    const selling = firstObj(it.sellingStatus);
    let price = 0;
    let currency = 'EUR';
    if (selling) {
      const cp = firstObj(selling.currentPrice);
      if (cp) {
        const val = cp.__value__;
        if (typeof val === 'string' || typeof val === 'number') {
          price = Number(val);
        }
        const cur = cp['@currencyId'];
        if (typeof cur === 'string') currency = cur;
      }
    }

    out.push({
      id: itemId,
      source: 'eBay',
      title,
      price: Number.isFinite(price) ? price : 0,
      currency,
      imageUrl: gallery,
      thumbnailUrl: gallery,
      listingUrl,
    });
  }

  return out;
}
