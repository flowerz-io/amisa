/**
 * Normalisation de la liste `enabledProviders` envoyée par le client (analyze-search, search-more).
 */
import type { ProviderKey } from './providers-config.js';

export const KNOWN_PROVIDERS: ProviderKey[] = ['vinted', 'grailed', 'ebay', 'depop', 'leboncoin'];

function normalizeProviderId(input: string): ProviderKey | null {
  const t = input.trim().toLowerCase().replace(/[\s_-]+/g, '');
  if (t === 'vinted') return 'vinted';
  if (t === 'grailed') return 'grailed';
  if (t === 'ebay') return 'ebay';
  if (t === 'depop') return 'depop';
  if (t === 'leboncoin') return 'leboncoin';
  return null;
}

export function normalizeRequestedProviders(input: unknown): ProviderKey[] {
  if (!Array.isArray(input)) return KNOWN_PROVIDERS;
  const out: ProviderKey[] = [];
  const seen = new Set<ProviderKey>();
  for (const raw of input) {
    if (typeof raw !== 'string') continue;
    const id = normalizeProviderId(raw);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    out.push(id);
  }
  return out.length > 0 ? out : KNOWN_PROVIDERS;
}
