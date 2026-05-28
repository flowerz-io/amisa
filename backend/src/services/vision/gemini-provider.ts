import type { FashionVisionResult } from '../../types.js';
import { GeminiVisionError, geminiErrorFromHttp } from './gemini-errors.js';

export interface GeminiVisionResult {
  identification: string;
  brand: string;
  model: string;
  exactColorway: string;
  dominantColor: string;
  secondaryColor: string;
  category: string;
  confidence: number;
}

const GEMINI_VISION_PROMPT = `Tu es un expert mondial en reconnaissance de vêtements, sneakers, accessoires et chaussures.

Tu as une culture très avancée des modèles exacts, collaborations, colorways, éditions limitées, archives sneakers et mode vintage.

Analyse l'image et identifie l'article principal avec le maximum de précision.

Réponds STRICTEMENT en JSON valide :

{
  "identification": "Marque modèle exact coloris exact simplifié",
  "brand": "",
  "model": "",
  "exactColorway": "",
  "dominantColor": "",
  "secondaryColor": "",
  "category": "",
  "confidence": 0
}

Règles :

* Priorité absolue au modèle exact.
* Si c'est une collaboration, l'inclure dans le modèle.
* Si un colorway exact est reconnaissable, le mettre dans exactColorway.
* identification doit rester utilisable pour Vinted.
* Ne pas inclure le SKU dans identification.
* Ne pas inclure de slash dans identification.
* Ne pas répéter la marque deux fois.
* Confidence entre 0 et 100.

Exemple attendu :
Image Adidas Wales Bonner :
{
  "identification": "Adidas Samba Nylon Wales Bonner Wonder Clay Royal",
  "brand": "Adidas",
  "model": "Samba Nylon Wales Bonner",
  "exactColorway": "Wonder Clay Royal",
  "dominantColor": "Beige",
  "secondaryColor": "Blue",
  "category": "chaussures · sneakers",
  "confidence": 95
}`;

function extractJsonObject(raw: string): string | null {
  const t = raw.replace(/```(?:json)?\s*|\s*```/gi, '').trim();
  const start = t.indexOf('{');
  if (start < 0) return null;
  let depth = 0;
  for (let i = start; i < t.length; i++) {
    const ch = t[i];
    if (ch === '{') depth++;
    else if (ch === '}') {
      depth--;
      if (depth === 0) return t.slice(start, i + 1);
    }
  }
  return null;
}

function str(v: unknown): string {
  if (v == null) return '';
  return String(v).trim();
}

function clampConfidence(v: unknown): number {
  const n = Math.round(Number(v));
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, n));
}

export function parseGeminiVisionJson(raw: string): GeminiVisionResult {
  const jsonStr = extractJsonObject(raw) ?? raw.trim();
  const j = JSON.parse(jsonStr) as Record<string, unknown>;
  return {
    identification: str(j.identification),
    brand: str(j.brand),
    model: str(j.model),
    exactColorway: str(j.exactColorway),
    dominantColor: str(j.dominantColor),
    secondaryColor: str(j.secondaryColor),
    category: str(j.category),
    confidence: clampConfidence(j.confidence),
  };
}

export function mapGeminiToFashionVision(g: GeminiVisionResult): FashionVisionResult {
  const brand = g.brand;
  const model = g.model;
  const identification =
    g.identification || [brand, model, g.exactColorway].filter(Boolean).join(' ');
  const confidence = g.confidence / 100;

  return {
    category: g.category || undefined,
    subcategory: undefined,
    dominantItem: identification || undefined,
    probableBrand: brand || undefined,
    color: g.dominantColor || undefined,
    material: undefined,
    styleKeywords: g.secondaryColor ? [g.secondaryColor] : undefined,
    confidence,
    sourceConfidence: confidence,
    inferredModel: model || undefined,
    dominantColorPrecise: g.exactColorway || g.dominantColor || undefined,
    itemTypeCanonical: g.category ? g.category.toLowerCase() : undefined,
    exactModel: model || undefined,
    colorway: g.exactColorway || undefined,
    fullIdentification: identification || undefined,
    visualReasoning: undefined,
    searchQueries: undefined,
  };
}

export async function analyzeGeminiVision(imageBase64: string): Promise<FashionVisionResult> {
  const key = process.env.GEMINI_API_KEY?.trim();
  if (!key) {
    throw new GeminiVisionError(
      'gemini_not_configured',
      'GEMINI_API_KEY is missing while VISION_PROVIDER=gemini.'
    );
  }

  console.log('[GEMINI_VISION_START]');

  const model = process.env.GEMINI_VISION_MODEL?.trim() || 'gemini-2.0-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;

  const t0 = performance.now();
  let res: Response;
  try {
    res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [
              { text: GEMINI_VISION_PROMPT },
              {
                inline_data: {
                  mime_type: 'image/jpeg',
                  data: imageBase64,
                },
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.2,
          responseMimeType: 'application/json',
        },
      }),
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log(`[GEMINI_VISION_ERROR] code=network message=${msg}`);
    throw new GeminiVisionError('gemini_network_error', msg);
  }

  if (!res.ok) {
    const errBody = await res.text().catch(() => '');
    const err = geminiErrorFromHttp(res.status, errBody);
    console.log(`[GEMINI_VISION_ERROR] code=${err.code} http=${res.status}`);
    throw err;
  }

  const payload = (await res.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  const raw =
    payload.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!raw.trim()) {
    console.log('[GEMINI_VISION_ERROR] code=empty_response');
    throw new GeminiVisionError('gemini_empty_response', 'Gemini returned an empty vision response.');
  }

  let parsed: GeminiVisionResult;
  try {
    parsed = parseGeminiVisionJson(raw);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.log(`[GEMINI_VISION_ERROR] code=invalid_json message=${msg}`);
    throw new GeminiVisionError('gemini_invalid_json', `Gemini JSON parse failed: ${msg}`);
  }

  console.log(`[GEMINI_VISION_SUCCESS] identification=${parsed.identification}`);
  console.log(
    `[GEMINI_VISION_SUCCESS] brand=${parsed.brand} model=${parsed.model} colorway=${parsed.exactColorway} confidence=${parsed.confidence}`
  );

  const ms = Math.round(performance.now() - t0);
  console.log(`[PERF] gemini_vision=${ms}ms`);

  return mapGeminiToFashionVision(parsed);
}
