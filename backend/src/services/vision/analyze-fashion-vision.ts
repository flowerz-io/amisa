import type { FashionVisionResult } from '../../types.js';
import { visionProviderName } from '../../config.js';
import { isOpenAIVisionFallbackAllowed } from '../../lib/vision-fallback-env.js';
import { GeminiVisionError } from './gemini-errors.js';
import { analyzeGeminiVision } from './gemini-provider.js';
import {
  analyzeOpenAIFashionVision,
  MOCK_OPENAI_VISION,
} from './openai-provider.js';

function textOnlyVisionResult(textQuery: string): FashionVisionResult {
  const q = textQuery.trim();
  return {
    category: 'search',
    dominantItem: q,
    probableBrand: '',
    color: '',
    confidence: 0.9,
    sourceConfidence: 0.9,
    inferredModel: q,
    itemTypeCanonical: 'query',
    fullIdentification: q,
  };
}

async function tryOpenAIFallback(
  imageBase64: string,
  reason: string
): Promise<FashionVisionResult | null> {
  if (!isOpenAIVisionFallbackAllowed()) {
    console.log('[OPENAI_FALLBACK_DISABLED]');
    return null;
  }
  if (!process.env.OPENAI_API_KEY?.trim()) {
    console.log('[OPENAI_FALLBACK_DISABLED] reason=no_openai_key');
    return null;
  }
  console.log(`[OPENAI_FALLBACK_USED] reason=${reason}`);
  return analyzeOpenAIFashionVision(imageBase64);
}

async function analyzeImageVision(imageBase64: string): Promise<FashionVisionResult> {
  if (visionProviderName === 'gemini') {
    try {
      return await analyzeGeminiVision(imageBase64);
    } catch (e) {
      if (e instanceof GeminiVisionError) {
        const fallback = await tryOpenAIFallback(imageBase64, e.code);
        if (fallback) return fallback;
        throw e;
      }
      const msg = e instanceof Error ? e.message : String(e);
      console.log(`[GEMINI_VISION_ERROR] code=unknown message=${msg}`);
      const fallback = await tryOpenAIFallback(imageBase64, 'unknown');
      if (fallback) return fallback;
      throw new GeminiVisionError('gemini_vision_failed', msg);
    }
  }

  if (visionProviderName === 'openai') {
    return analyzeOpenAIFashionVision(imageBase64);
  }

  console.log('[VISION_PROVIDER] mock (no vision API key)');
  return MOCK_OPENAI_VISION;
}

export async function analyzeFashionVision(
  imageBase64: string | undefined,
  textQuery: string | undefined
): Promise<FashionVisionResult> {
  const t0 = performance.now();

  if (textQuery && textQuery.trim().length > 0 && !imageBase64) {
    const ms = Math.round(performance.now() - t0);
    console.log(`[PERF] vision=${ms}ms (text-only skip)`);
    return textOnlyVisionResult(textQuery);
  }

  if (!imageBase64) {
    console.log('[PERF] vision=0ms (no image)');
    return MOCK_OPENAI_VISION;
  }

  const result = await analyzeImageVision(imageBase64);
  const ms = Math.round(performance.now() - t0);
  console.log(`[PERF] vision=${ms}ms provider=${visionProviderName}`);
  return result;
}

export { GeminiVisionError } from './gemini-errors.js';
