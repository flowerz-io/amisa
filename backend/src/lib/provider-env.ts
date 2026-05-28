/**
 * Railway : Vinted uniquement (`VINTED_ENABLED` strictement `true`).
 */

/** Uniquement la chaîne `true` (insensible à la casse après trim). */
export function isEnvStrictlyTrue(key: string): boolean {
  return process.env[key]?.trim().toLowerCase() === 'true';
}

export interface ServerProviderGate {
  ready: boolean;
  /** Raison log / debug (ex. VINTED_ENABLED_false) */
  reason: string;
}

export function gateVintedServer(): ServerProviderGate {
  if (!isEnvStrictlyTrue('VINTED_ENABLED')) {
    return { ready: false, reason: 'VINTED_ENABLED_false' };
  }
  return { ready: true, reason: 'ok' };
}

/**
 * Variables utiles au démarrage (aucun secret affiché en clair sauf longueur token).
 * @see backend/ENV.md pour la liste complète.
 */
export function logProviderEnvironmentDiagnostics(): void {
  const nodeEnv = process.env.NODE_ENV ?? '<unset>';
  const useMock = process.env.USE_MOCK ?? '<unset>';
  const mockMode = process.env.MOCK_MODE ?? '<unset>';
  const vision = process.env.VISION_PROVIDER ?? '<unset>';

  console.log('[ENV_BACKEND]');
  console.log(`  NODE_ENV=${nodeEnv}`);
  console.log(`  VISION_PROVIDER=${vision}`);
  console.log(`  USE_MOCK=${useMock}`);
  console.log(`  MOCK_MODE=${mockMode}`);
  console.log(`  VINTED_ENABLED=${process.env.VINTED_ENABLED ?? '<unset>'}`);

  const token = process.env.VINTED_ACCESS_TOKEN;
  console.log(
    `  VINTED_ACCESS_TOKEN=${token && token.length > 0 ? `set(len=${token.length})` : '<unset>'}`
  );
  console.log(`  VINTED_API_BASE=${process.env.VINTED_API_BASE ?? '<default api/v2>'}`);
  console.log(`  MAX_RESULTS_PER_SEARCH=${process.env.MAX_RESULTS_PER_SEARCH ?? '<default 100>'}`);
  console.log(`  VINTED_SCRAPER_PER_PAGE=${process.env.VINTED_SCRAPER_PER_PAGE ?? '<default 24>'}`);

  const openai = process.env.OPENAI_API_KEY;
  const gemini = process.env.GEMINI_API_KEY;
  console.log(
    `  OPENAI_API_KEY=${openai && openai.length > 0 ? `set(len=${openai.length})` : '<unset>'}`
  );
  console.log(
    `  GEMINI_API_KEY=${gemini && gemini.length > 0 ? `set(len=${gemini.length})` : '<unset>'}`
  );
  console.log(`  GEMINI_MODEL=${process.env.GEMINI_MODEL ?? process.env.GEMINI_VISION_MODEL ?? '<default gemini-2.0-flash>'}`);
  console.log(
    `  ALLOW_OPENAI_VISION_FALLBACK=${process.env.ALLOW_OPENAI_VISION_FALLBACK ?? '<unset>'}`
  );
  console.log(`  DEBUG_PROVIDER_ROUTE=${process.env.DEBUG_PROVIDER_ROUTE ?? '<unset>'} (mettre 0 pour désactiver /debug-vinted)`);
}
