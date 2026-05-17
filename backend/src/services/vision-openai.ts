import OpenAI from 'openai';
import type { FashionVisionResult } from '../types.js';
import { visionProviderName } from '../config.js';

const MOCK_VISION: FashionVisionResult = {
  category: 'footwear',
  subcategory: 'sneakers',
  dominantItem: 'leather sneakers',
  probableBrand: '',
  color: 'white',
  material: 'leather',
  styleKeywords: [],
  confidence: 0.5,
  sourceConfidence: 0.5,
  inferredModel: 'sneaker',
  dominantColorPrecise: 'white',
  itemTypeCanonical: 'sneakers',
};

export async function analyzeFashionVision(
  imageBase64: string | undefined,
  textQuery: string | undefined
): Promise<FashionVisionResult> {
  const t0 = performance.now();

  if (textQuery && textQuery.trim().length > 0 && !imageBase64) {
    const ms = Math.round(performance.now() - t0);
    console.log(`[PERF] vision=${ms}ms (text-only skip)`);
    return {
      category: 'search',
      dominantItem: textQuery.trim(),
      probableBrand: '',
      color: '',
      confidence: 0.9,
      sourceConfidence: 0.9,
      inferredModel: textQuery.trim(),
      itemTypeCanonical: 'query',
    };
  }

  if (!imageBase64) {
    console.log(`[PERF] vision=0ms (no image)`);
    return MOCK_VISION;
  }

  const key = process.env.OPENAI_API_KEY;
  if (!key || visionProviderName === 'mock') {
    const ms = Math.round(performance.now() - t0);
    console.log(`[PERF] vision=${ms}ms (mock)`);
    return MOCK_VISION;
  }

  const client = new OpenAI({ apiKey: key });
  const prompt = `You are a fashion product analyst. From the image, output ONLY compact JSON with keys:
category, subcategory, dominantItem, probableBrand, color, material, styleKeywords (array), confidence (0-1), sourceConfidence (0-1), inferredEntity, secondaryMarking, inferredModel, dominantColorPrecise, itemTypeCanonical.
Use empty string for unknown strings. Be concise.`;

  const completion = await client.chat.completions.create({
    model: process.env.OPENAI_VISION_MODEL ?? 'gpt-4o-mini',
    max_tokens: 400,
    messages: [
      {
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          {
            type: 'image_url',
            image_url: {
              url: `data:image/jpeg;base64,${imageBase64}`,
            },
          },
        ],
      },
    ],
  });

  const raw = completion.choices[0]?.message?.content ?? '{}';
  let parsed: FashionVisionResult = MOCK_VISION;
  try {
    const j = JSON.parse(raw.replace(/```json\n?|\n?```/g, '').trim()) as Record<string, unknown>;
    parsed = {
      category: String(j.category ?? ''),
      subcategory: String(j.subcategory ?? ''),
      dominantItem: String(j.dominantItem ?? ''),
      probableBrand: String(j.probableBrand ?? ''),
      color: String(j.color ?? ''),
      material: String(j.material ?? ''),
      styleKeywords: Array.isArray(j.styleKeywords)
        ? (j.styleKeywords as unknown[]).map((x) => String(x))
        : [],
      confidence: Number(j.confidence ?? 0.5),
      sourceConfidence: Number(j.sourceConfidence ?? 0.5),
      inferredEntity: j.inferredEntity ? String(j.inferredEntity) : undefined,
      secondaryMarking: j.secondaryMarking ? String(j.secondaryMarking) : undefined,
      inferredModel: j.inferredModel ? String(j.inferredModel) : undefined,
      dominantColorPrecise: j.dominantColorPrecise
        ? String(j.dominantColorPrecise)
        : undefined,
      itemTypeCanonical: j.itemTypeCanonical
        ? String(j.itemTypeCanonical)
        : undefined,
    };
  } catch {
    /* keep mock */
  }

  const ms = Math.round(performance.now() - t0);
  console.log(`[PERF] vision=${ms}ms`);
  return parsed;
}
