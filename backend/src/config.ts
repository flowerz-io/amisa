export type VisionProviderName = 'gemini' | 'openai' | 'mock';

/**
 * `VISION_PROVIDER=gemini` + `GEMINI_API_KEY` → Gemini.
 * Sinon OpenAI si clé présente, sinon mock.
 */
export function resolveVisionProvider(): VisionProviderName {
  const requested = process.env.VISION_PROVIDER?.trim().toLowerCase();
  if (requested === 'gemini' && process.env.GEMINI_API_KEY?.trim()) {
    return 'gemini';
  }
  if (process.env.OPENAI_API_KEY?.trim()) {
    return 'openai';
  }
  return 'mock';
}

export const visionProviderName: VisionProviderName = resolveVisionProvider();

export function logVisionProviderDiagnostic(): void {
  console.log(`[VISION_PROVIDER] ${visionProviderName}`);
}
