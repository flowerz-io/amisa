/**
 * Activation stricte des providers Railway : *_ENABLED doit valoir exactement "true".
 * Plus de liste globale implicite "tous actifs" si PROVIDERS_ENABLED est absent.
 */

import { getEbayDebugSnapshot, hasEbayOAuthCredentials } from './ebay-env.js';

/** Uniquement la chaîne `true` (insensible à la casse après trim). */
export function isEnvStrictlyTrue(key: string): boolean {
  return process.env[key]?.trim().toLowerCase() === 'true';
}

export interface ServerProviderGate {
  ready: boolean;
  /** Raison log / debug (ex. missing_token) */
  reason: string;
}

export function gateEbayServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('EBAY_ENABLED')) {
    return { ready: false, reason: 'EBAY_ENABLED_false' };
  }
  if (!hasEbayOAuthCredentials()) {
    return { ready: false, reason: 'missing_ebay_oauth_credentials' };
  }
  return { ready: true, reason: 'ok' };
}

export function gateVintedServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('VINTED_ENABLED')) {
    return { ready: false, reason: 'VINTED_ENABLED_false' };
  }
  if (!process.env.VINTED_ACCESS_TOKEN?.trim()) {
    return { ready: false, reason: 'missing_token' };
  }
  return { ready: true, reason: 'ok' };
}

export function gateGrailedServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('GRAILED_ENABLED')) {
    return { ready: false, reason: 'GRAILED_ENABLED_false' };
  }
  return { ready: true, reason: 'ok' };
}

export function gateDepopServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('DEPOP_ENABLED')) {
    return { ready: false, reason: 'DEPOP_ENABLED_false' };
  }
  return { ready: true, reason: 'ok' };
}

export function gateLeboncoinServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('LEBONCOIN_ENABLED')) {
    return { ready: false, reason: 'LEBONCOIN_ENABLED_false' };
  }
  return { ready: true, reason: 'ok' };
}

export function logProviderEnvironmentDiagnostics(): void {
  const nodeEnv = process.env.NODE_ENV ?? '<unset>';
  const useMock = process.env.USE_MOCK ?? '<unset>';
  const mockMode = process.env.MOCK_MODE ?? '<unset>';
  const ebaySnap = getEbayDebugSnapshot();

  console.log('[ENV_MARKETPLACES]');
  console.log(`  NODE_ENV=${nodeEnv}`);
  console.log(`  USE_MOCK=${useMock}`);
  console.log(`  MOCK_MODE=${mockMode}`);
  console.log(
    `  *_ENABLED strict=true only — defaults off unless VINTED_ENABLED=true etc.`
  );
  console.log(`  EBAY_ENABLED raw=${process.env.EBAY_ENABLED ?? '<unset>'}`);
  console.log(
    `  ebayAppCredentialPresent=${ebaySnap.appIdPresent} (resolvedFrom=${ebaySnap.appIdSource})`
  );
  console.log(
    `  ebayGlobalIdUsed=${ebaySnap.globalId} (resolvedFrom=${ebaySnap.globalIdSource})`
  );
  console.log(
    `  EBAY_ENV=${process.env.EBAY_ENV ?? '<unset>'} EBAY_CLIENT_SECRET=${process.env.EBAY_CLIENT_SECRET ? 'set(len>0)' : '<unset>'}`
  );

  const extra = [
    'VINTED_ENABLED',
    'GRAILED_ENABLED',
    'DEPOP_ENABLED',
    'LEBONCOIN_ENABLED',
    'EBAY_CLIENT_ID',
    'EBAY_CLIENT_SECRET',
    'EBAY_GLOBAL_ID',
    'EBAY_MARKETPLACE_ID',
    'EBAY_RESULTS_LIMIT_PER_QUERY',
    'MAX_RESULTS_PER_SEARCH',
    'VINTED_ACCESS_TOKEN',
    'DEBUG_PROVIDER_ROUTE',
  ] as const;
  for (const k of extra) {
    const v = process.env[k];
    if (v === undefined) {
      console.log(`  ${k}=<unset>`);
    } else if (
      k === 'EBAY_CLIENT_ID' ||
      k === 'EBAY_CLIENT_SECRET' ||
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
