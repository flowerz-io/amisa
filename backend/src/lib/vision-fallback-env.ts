/** Fallback OpenAI après échec Gemini — désactivé par défaut. */
export function isOpenAIVisionFallbackAllowed(): boolean {
  return process.env.ALLOW_OPENAI_VISION_FALLBACK?.trim().toLowerCase() === 'true';
}
