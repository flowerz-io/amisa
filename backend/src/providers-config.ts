/** Providers autorisés côté Railway ; l’app filtre via `enabledProviders`. */
export const PROVIDERS_ENABLED = ['vinted', 'grailed', 'ebay', 'depop', 'leboncoin'] as const;

export type ProviderKey = (typeof PROVIDERS_ENABLED)[number];
