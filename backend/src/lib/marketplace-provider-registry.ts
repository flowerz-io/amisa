/**
 * Registre des marketplaces — extensible (API officielles / affiliés).
 * Aucun contournement anti-bot : intégrations stables uniquement.
 */

export type MarketplaceProviderId =
  | 'vinted'
  | 'ebay'
  | 'vestiaire'
  | 'grailed'
  | 'depop';

export type ProviderIntegrationKind =
  | 'api'
  | 'affiliate'
  | 'scraper_limited';

export interface MarketplaceProviderDescriptor {
  id: MarketplaceProviderId;
  displayName: string;
  integrationKind: ProviderIntegrationKind;
  /** Activé côté serveur (gate env / feature flag). */
  enabled: boolean;
}

/** Providers planifiés — Vinted seul actif aujourd’hui. */
export const MARKETPLACE_PROVIDERS: readonly MarketplaceProviderDescriptor[] = [
  {
    id: 'vinted',
    displayName: 'Vinted',
    integrationKind: 'scraper_limited',
    enabled: true,
  },
  {
    id: 'ebay',
    displayName: 'eBay',
    integrationKind: 'api',
    enabled: false,
  },
  {
    id: 'vestiaire',
    displayName: 'Vestiaire Collective',
    integrationKind: 'api',
    enabled: false,
  },
  {
    id: 'grailed',
    displayName: 'Grailed',
    integrationKind: 'api',
    enabled: false,
  },
  {
    id: 'depop',
    displayName: 'Depop',
    integrationKind: 'api',
    enabled: false,
  },
] as const;

export function getProviderDescriptor(
  id: MarketplaceProviderId
): MarketplaceProviderDescriptor | undefined {
  return MARKETPLACE_PROVIDERS.find((p) => p.id === id);
}
