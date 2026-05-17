/**
 * Variables d’environnement Railway / local pour l’exécution des providers.
 * Aucun provider n’est coupé silencieusement : ici on ne fait qu’exposer l’état pour les logs.
 */

const Falsy = new Set(['0', 'false', 'no', 'off', '']);

/** `VAR` absent = activé ; explicite false désactive côté serveur. */
export function envProviderEnabled(envKey: string): boolean {
  const v = process.env[envKey];
  if (v === undefined || v === '') return true;
  return !Falsy.has(v.trim().toLowerCase());
}

/** Liste globale optionnelle : PROVIDERS_ENABLED=vinted,ebay ou "all". */
export function parseGlobalProvidersEnabledList(): Set<string> | null {
  const raw = process.env.PROVIDERS_ENABLED;
  if (raw === undefined || raw === '' || raw.toLowerCase() === 'all') {
    return null;
  }
  const set = new Set(
    raw
      .split(/[,;\s]+/)
      .map((s) => s.trim().toLowerCase())
      .filter(Boolean)
  );
  return set.size ? set : null;
}

/** true si le client (`enabledProviders`) ET le serveur autorisent ce provider. */
export function isProviderRunnable(
  name: string,
  clientEnabled: Set<string>
): boolean {
  if (!clientEnabled.has(name.toLowerCase())) return false;
  const perVar: Record<string, string> = {
    vinted: 'VINTED_ENABLED',
    ebay: 'EBAY_ENABLED',
    grailed: 'GRAILED_ENABLED',
    depop: 'DEPOP_ENABLED',
    leboncoin: 'LEBONCOIN_ENABLED',
  };
  const key = perVar[name.toLowerCase()];
  if (key && !envProviderEnabled(key)) {
    console.warn(`[PROVIDER_SKIP_SERVER] ${name} disabled via ${key}=false`);
    return false;
  }
  const g = parseGlobalProvidersEnabledList();
  if (g && !g.has(name.toLowerCase())) {
    console.warn(
      `[PROVIDER_SKIP_SERVER] ${name} not in PROVIDERS_ENABLED=${process.env.PROVIDERS_ENABLED}`
    );
    return false;
  }
  return true;
}

export function logProviderEnvironmentDiagnostics(): void {
  const keys = [
    'NODE_ENV',
    'USE_MOCK',
    'MOCK_MODE',
    'PROVIDERS_ENABLED',
    'VINTED_ENABLED',
    'EBAY_ENABLED',
    'GRAILED_ENABLED',
    'DEPOP_ENABLED',
    'LEBONCOIN_ENABLED',
    'EBAY_APP_ID',
    'EBAY_GLOBAL_ID_V2',
    'VINTED_ACCESS_TOKEN',
    'DEBUG_PROVIDER_ROUTE',
  ] as const;
  console.log('[ENV_MARKETPLACES]');
  for (const k of keys) {
    const v = process.env[k];
    if (v === undefined) {
      console.log(`  ${k}=<unset>`);
    } else if (
      k === 'EBAY_APP_ID' ||
      k === 'VINTED_ACCESS_TOKEN'
    ) {
      console.log(
        `  ${k}=${v.length > 0 ? `set(len=${v.length})` : '<empty>'}`
      );
    } else {
      console.log(`  ${k}=${v}`);
    }
  }
}
