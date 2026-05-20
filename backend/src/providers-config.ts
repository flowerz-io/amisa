/** Seul Vinted est supporté. */
export const PROVIDERS_ENABLED = ['vinted'] as const;

export type ProviderKey = (typeof PROVIDERS_ENABLED)[number];
