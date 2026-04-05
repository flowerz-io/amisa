/**
 * Activation centralisée des providers marketplace.
 * Prévu pour activer/désactiver rapidement un provider sans toucher la logique de scraping.
 */

export type ProviderKey = 'vinted' | 'grailed' | 'leboncoin' | 'ebay' | 'depop';

function envEnabled(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (!raw) return fallback;
  const t = raw.trim().toLowerCase();
  if (['1', 'true', 'yes', 'on'].includes(t)) return true;
  if (['0', 'false', 'no', 'off'].includes(t)) return false;
  return fallback;
}

export const PROVIDERS_ENABLED: Record<ProviderKey, boolean> = {
  vinted: envEnabled('PROVIDER_VINTED_ENABLED', true),
  grailed: envEnabled('PROVIDER_GRAILED_ENABLED', true),
  ebay: envEnabled('PROVIDER_EBAY_ENABLED', true),
  depop: envEnabled('PROVIDER_DEPOP_ENABLED', true),
  // Désactivé par défaut : challenge anti-bot/captcha côté plateforme.
  leboncoin: envEnabled('PROVIDER_LEBONCOIN_ENABLED', false),
};

export function isProviderEnabled(provider: ProviderKey): boolean {
  return PROVIDERS_ENABLED[provider] === true;
}

