/**
 * Configuration backend — provider, debug, etc.
 */

export const isDebug =
  process.env.DEBUG === '1' ||
  process.env.DEBUG === 'true' ||
  process.env.NODE_ENV === 'development';

function getVisionProviderName(): 'openai' | 'mock' {
  if (process.env.VISION_PROVIDER === 'mock') {
    return 'mock';
  }
  if (process.env.VISION_PROVIDER === 'openai') {
    return 'openai';
  }
  return process.env.OPENAI_API_KEY ? 'openai' : 'mock';
}

export const visionProviderName = getVisionProviderName();

/** Diagnostic au démarrage : clé API, provider sélectionné, fallback éventuel. */
export function logVisionProviderDiagnostic(): void {
  const key = process.env.OPENAI_API_KEY;
  const keyStatus = key ? 'present' : 'missing';
  const keyPrefix = key ? key.slice(0, 8) + '...' : '(none)';

  console.log(`OPENAI_API_KEY=${keyStatus}`);
  console.log(`OPENAI_API_KEY_prefix=${keyPrefix}`);

  const selected = visionProviderName;
  console.log(`[VISION_PROVIDER_SELECTED] ${selected}`);

  if (key && selected === 'mock') {
    console.log(
      '[VISION_FALLBACK_TRIGGERED] reason=VISION_PROVIDER=mock overrides OPENAI_API_KEY'
    );
  } else if (!key && selected === 'mock') {
    console.log(
      '[VISION_FALLBACK_TRIGGERED] reason=OPENAI_API_KEY missing, using mock'
    );
  }
}
