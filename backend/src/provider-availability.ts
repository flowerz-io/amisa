/**
 * Statut de disponibilité d’un provider — logique partagée (eBay API, scrapers, etc.).
 */
import type { ProviderAvailabilityDTO } from './api/types.js';

export type { ProviderAvailabilityDTO, ProviderAvailabilityStatus } from './api/types.js';

/** Résultat interne eBay / scrapers avant normalisation client. */
export type EbayInternalStopReason =
  | 'ok'
  | 'api_error'
  | 'credentials_missing'
  | 'provider_blocked_by_challenge'
  | 'dom_not_ready'
  | 'page_closed'
  | 'page_crashed'
  | 'provider_unavailable';

/**
 * Mappe le résultat eBay vers le statut exposé au client.
 * Ne pas confondre « vide » (no_results) et « bloqué » (blocked_by_challenge).
 */
export function ebayToProviderAvailability(
  stopReason: EbayInternalStopReason | string | undefined,
  itemsCount: number,
  totalCount?: number
): ProviderAvailabilityDTO {
  if (stopReason === 'provider_blocked_by_challenge') {
    return { status: 'blocked_by_challenge', reason: 'challenge_detected' };
  }
  if (stopReason === 'api_error' || stopReason === 'credentials_missing') {
    return { status: 'provider_error', reason: String(stopReason) };
  }
  if (stopReason === 'ok') {
    if (itemsCount > 0) return { status: 'ok' };
    const t = totalCount ?? 0;
    if (t === 0) return { status: 'no_results', reason: 'empty_catalog' };
    return { status: 'provider_error', reason: 'parse_failed_despite_total' };
  }
  if (stopReason === undefined) {
    return { status: 'provider_error', reason: 'unknown' };
  }
  return { status: 'provider_error', reason: String(stopReason) };
}

export function availabilityToLogLine(provider: string, dto: ProviderAvailabilityDTO): string {
  return `[${provider.toUpperCase()}_STATUS] ${dto.status}${dto.reason ? ` reason=${dto.reason}` : ''}`;
}
