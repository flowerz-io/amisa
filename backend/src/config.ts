/**
 * Configuration backend — provider vision, debug, etc.
 *
 * VISION_PROVIDER accepte : "gemini" | "openai" | "mock"
 * Auto-détection si absent : GEMINI_API_KEY → gemini, OPENAI_API_KEY → openai, sinon mock.
 */

export const isDebug =
  process.env.DEBUG === '1' ||
  process.env.DEBUG === 'true' ||
  process.env.NODE_ENV === 'development';

function getVisionProviderName(): 'gemini' | 'openai' | 'mock' {
  const explicit = process.env.VISION_PROVIDER;
  if (explicit === 'mock')   return 'mock';
  if (explicit === 'openai') return 'openai';
  if (explicit === 'gemini') return 'gemini';

  // Auto-detect : Gemini prioritaire sur OpenAI.
  if (process.env.GEMINI_API_KEY)  return 'gemini';
  if (process.env.OPENAI_API_KEY)  return 'openai';
  return 'mock';
}

export const visionProviderName = getVisionProviderName();

/** Diagnostic au démarrage : clés API, provider sélectionné, fallback éventuel. */
export function logVisionProviderDiagnostic(): void {
  const openaiKey = process.env.OPENAI_API_KEY;
  const geminiKey = process.env.GEMINI_API_KEY;

  console.log(`OPENAI_API_KEY=${openaiKey ? 'present' : 'missing'}`);
  console.log(`GEMINI_API_KEY=${geminiKey ? 'present' : 'missing'}`);
  if (geminiKey) console.log(`GEMINI_API_KEY_prefix=${geminiKey.slice(0, 8)}...`);

  const selected = visionProviderName;
  console.log(`[VISION_PROVIDER_SELECTED] ${selected}`);

  if (!openaiKey && !geminiKey && selected === 'mock') {
    console.log('[VISION_FALLBACK_TRIGGERED] reason=no API key found, using mock');
  } else if (process.env.VISION_PROVIDER === 'mock') {
    console.log('[VISION_FALLBACK_TRIGGERED] reason=VISION_PROVIDER=mock override');
  }
}
