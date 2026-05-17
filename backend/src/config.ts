export const visionProviderName =
  process.env.OPENAI_API_KEY ? 'openai' : 'mock';

export function logVisionProviderDiagnostic(): void {
  console.log(`[VISION_PROVIDER] ${visionProviderName}`);
}
