import type { FashionVisionResult } from '../../types.js';

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

const GEMINI_VISION_PROMPT = `Tu es un expert mondial en identification de vêtements, sneakers, accessoires et pièces de mode vintage ou modernes.

Tu possèdes une connaissance extrêmement avancée :
- archives sneakers,
- colorways,
- références produit,
- collaborations,
- silhouettes,
- branding,
- collections.

Analyse cette image et identifie l'article EXACT.

IMPORTANT :
- Priorité absolue au vrai modèle exact.
- Évite les approximations.
- Si tu reconnais précisément le modèle, indique-le.
- Si tu n'es pas certain, indique la version la plus probable.
- Ignore le décor et concentre-toi uniquement sur l'article principal.

Réponds STRICTEMENT en JSON valide :

{
  "identification": "Marque + modèle exact + coloris principal simplifié",
  "brand": "",
  "model": "",
  "exactColorway": "",
  "dominantColor": "",
  "secondaryColor": "",
  "category": "",
  "confidence": 0
}

Règles :
- "identification" doit être optimisé pour une marketplace comme Vinted.
- Ne PAS inclure le SKU dans "identification".
- Ne PAS inclure les nuances complexes dans "identification".
- "dominantColor" doit être une couleur simple : Blue, Black, White, Brown, Grey, Green, Red, Yellow, Beige, Pink, Purple, Orange.
- "exactColorway" peut contenir le vrai colorway détaillé.
- confidence = entier de 0 à 100.`;

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
  const identification = g.identification || [brand, model, g.dominantColor].filter(Boolean).join(' ');
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

function logGeminiVision(g: GeminiVisionResult): void {
  console.log(`[GEMINI_VISION] identification=${g.identification}`);
  console.log(
    `[GEMINI_VISION] brand=${g.brand} model=${g.model} color=${g.dominantColor} confidence=${g.confidence}`
  );
}

export async function analyzeGeminiVision(imageBase64: string): Promise<FashionVisionResult> {
  const key = process.env.GEMINI_API_KEY?.trim();
  if (!key) {
    throw new Error('GEMINI_API_KEY missing');
  }

  const model = process.env.GEMINI_VISION_MODEL?.trim() || 'gemini-2.0-flash';
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${encodeURIComponent(key)}`;

  const t0 = performance.now();
  const res = await fetch(url, {
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

  if (!res.ok) {
    const errBody = await res.text().catch(() => '');
    throw new Error(`Gemini HTTP ${res.status}: ${errBody.slice(0, 400)}`);
  }

  const payload = (await res.json()) as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string }> };
    }>;
  };

  const raw =
    payload.candidates?.[0]?.content?.parts?.map((p) => p.text ?? '').join('') ?? '';
  if (!raw.trim()) {
    throw new Error('Gemini empty response');
  }

  const parsed = parseGeminiVisionJson(raw);
  logGeminiVision(parsed);

  const ms = Math.round(performance.now() - t0);
  console.log(`[PERF] gemini_vision=${ms}ms`);

  return mapGeminiToFashionVision(parsed);
}
