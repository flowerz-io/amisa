/**
 * vision-orchestrator.ts
 *
 * Couche d'orchestration vision : provider principal (Gemini par défaut),
 * fallback automatique vers OpenAI sur quota/rate-limit/indisponibilité.
 *
 * Aucune autre route ne doit appeler les providers directement.
 */

import { GoogleGenerativeAIFetchError } from '@google/generative-ai';
import type { VisionAnalyzeResult } from './types.js';
import { geminiVisionProvider } from './gemini-provider.js';
import { openaiVisionProvider } from './openai-provider.js';
import { mockVisionProvider } from './mock-provider.js';
import { visionProviderName } from '../config.js';

// ---------------------------------------------------------------------------
// Timeouts
// ---------------------------------------------------------------------------

const GEMINI_TIMEOUT_MS  = 30_000;
const OPENAI_TIMEOUT_MS  = 45_000;

function withTimeout<T>(promise: Promise<T>, ms: number, label: string): Promise<T> {
  return Promise.race([
    promise,
    new Promise<T>((_, reject) =>
      setTimeout(
        () => reject(new Error(`[TIMEOUT] ${label} timed out after ${ms}ms`)),
        ms,
      )
    ),
  ]);
}

// ---------------------------------------------------------------------------
// Résultat enrichi (provider réellement utilisé)
// ---------------------------------------------------------------------------

export interface VisionOrchestrationResult extends VisionAnalyzeResult {
  /** Provider qui a effectivement répondu : "gemini" | "openai-fallback" | "openai" | "mock" */
  usedProvider: string;
}

// ---------------------------------------------------------------------------
// Détection des erreurs Gemini éligibles au fallback
// ---------------------------------------------------------------------------

const FALLBACK_KEYWORDS = [
  'quota',
  'rate limit',
  'resource exhausted',
  'overloaded',
  'unavailable',
  'too many requests',
  '429',
  '[timeout]',
  'empty response',
];

/**
 * Renvoie true uniquement si l'erreur est liée au service Gemini lui-même
 * (quota, rate limit, indisponibilité, timeout), pas à notre pipeline.
 */
export function shouldFallbackFromGemini(error: unknown): boolean {
  // Timeout déclenché par withTimeout
  if (error instanceof Error && error.message.toLowerCase().includes('[timeout]')) {
    return true;
  }

  // Erreur HTTP Gemini SDK — status explicite
  if (error instanceof GoogleGenerativeAIFetchError) {
    const retriable = [429, 500, 503, 504, 529];
    if (error.status != null && retriable.includes(error.status)) {
      return true;
    }
    const text = (error.statusText ?? '').toLowerCase();
    if (FALLBACK_KEYWORDS.some(k => text.includes(k))) {
      return true;
    }
  }

  // Inspection message générique (SDK peut envelopper différemment selon version)
  if (error instanceof Error) {
    const msg = error.message.toLowerCase();
    if (FALLBACK_KEYWORDS.some(k => msg.includes(k))) {
      return true;
    }
  }

  return false;
}

// ---------------------------------------------------------------------------
// Orchestrateur principal
// ---------------------------------------------------------------------------

/**
 * Analyse une image en sélectionnant automatiquement le bon provider.
 *
 * - VISION_PROVIDER=mock  → mock direct
 * - VISION_PROVIDER=openai → OpenAI direct (pas de fallback)
 * - VISION_PROVIDER=gemini → Gemini avec fallback OpenAI si quota/rate-limit
 */
export async function analyzeWithFallback(
  imageBuffer: Buffer,
): Promise<VisionOrchestrationResult> {
  // ── Mock ──────────────────────────────────────────────────────────────────
  if (visionProviderName === 'mock') {
    const result = await mockVisionProvider.analyzeFashionItem(imageBuffer);
    return { ...result, usedProvider: 'mock' };
  }

  // ── OpenAI direct (pas de Gemini, pas de fallback) ───────────────────────
  if (visionProviderName === 'openai') {
    console.log('[OPENAI_ANALYSIS_START]');
    try {
      const result = await withTimeout(
        openaiVisionProvider.analyzeFashionItem(imageBuffer),
        OPENAI_TIMEOUT_MS,
        'OpenAI',
      );
      console.log('[OPENAI_ANALYSIS_SUCCESS]');
      return { ...result, usedProvider: 'openai' };
    } catch (err) {
      console.error('[OPENAI_ANALYSIS_FAILED]', formatError(err));
      console.error('[VISION_ANALYSIS_FINAL_FAILURE]');
      throw new Error('Vision analysis failed (OpenAI)');
    }
  }

  // ── Gemini avec fallback OpenAI ───────────────────────────────────────────
  try {
    const result = await withTimeout(
      geminiVisionProvider.analyzeFashionItem(imageBuffer),
      GEMINI_TIMEOUT_MS,
      'Gemini',
    );
    // [GEMINI_ANALYSIS_START] et [GEMINI_ANALYSIS_SUCCESS] loggués dans le provider.
    return { ...result, usedProvider: 'gemini' };
  } catch (geminiErr) {
    const errInfo = formatError(geminiErr);
    console.error('[GEMINI_ANALYSIS_FAILED]', errInfo);

    if (isQuotaError(geminiErr)) {
      console.error('[GEMINI_QUOTA_EXCEEDED]', errInfo);
    }

    // Erreur non éligible au fallback (bug local, image invalide…)
    if (!shouldFallbackFromGemini(geminiErr)) {
      console.error('[GEMINI_NO_FALLBACK] error not retriable — rethrowing');
      throw geminiErr;
    }

    // Fallback impossible faute de clé OpenAI
    if (!process.env.OPENAI_API_KEY) {
      console.error('[VISION_FALLBACK_UNAVAILABLE_NO_OPENAI_KEY]');
      throw new Error('Vision analysis failed: Gemini quota exceeded, no OpenAI key available');
    }

    // ── Fallback vers OpenAI ─────────────────────────────────────────────────
    console.log('[VISION_FALLBACK_TO_OPENAI]');
    console.log('[OPENAI_ANALYSIS_START]');
    try {
      const result = await withTimeout(
        openaiVisionProvider.analyzeFashionItem(imageBuffer),
        OPENAI_TIMEOUT_MS,
        'OpenAI-fallback',
      );
      console.log('[OPENAI_ANALYSIS_SUCCESS]');
      return { ...result, usedProvider: 'openai-fallback' };
    } catch (openaiErr) {
      console.error('[OPENAI_ANALYSIS_FAILED]', formatError(openaiErr));
      console.error('[VISION_ANALYSIS_FINAL_FAILURE] both Gemini and OpenAI failed');
      throw new Error('Vision analysis failed: both Gemini and OpenAI unavailable');
    }
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function isQuotaError(err: unknown): boolean {
  if (err instanceof GoogleGenerativeAIFetchError && err.status === 429) return true;
  if (err instanceof Error) {
    const m = err.message.toLowerCase();
    return m.includes('quota') || m.includes('resource exhausted') || m.includes('429');
  }
  return false;
}

function formatError(err: unknown): string {
  if (err instanceof GoogleGenerativeAIFetchError) {
    return `HTTP ${err.status} ${err.statusText} — ${err.message}`;
  }
  if (err instanceof Error) return err.message;
  return String(err);
}
