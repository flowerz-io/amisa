import OpenAI from 'openai';
import type { FashionVisionResult } from '../types.js';
import { visionProviderName } from '../config.js';

/** Prompt système : reconnaissance expert mode / précision modèle + coloris. */
const VISION_SYSTEM_PROMPT = `Tu es un expert mondial en reconnaissance de vêtements, chaussures et accessoires de mode.
Tu as une très grosse culture produit : sneakers, streetwear, luxe, vintage, sportswear, workwear, créateurs, collaborations, coloris commerciaux et variantes rares.

Ta mission :
identifier l'article principal visible sur l'image avec le plus de précision possible.

Priorité absolue :
ne donne pas seulement une catégorie générique.
Tu cherches le modèle exact probable.

Format de sortie JSON strict (une seule ligne ou plusieurs, mais UN SEUL objet JSON valide, sans texte avant ni après) :
{
  "brand": "marque probable",
  "exactModel": "modèle exact probable",
  "colorway": "coloris exact ou descriptif",
  "fullIdentification": "Marque + modèle exact + coloris",
  "category": "catégorie",
  "subcategory": "sous-catégorie",
  "material": "matière probable",
  "confidence": 0.0,
  "visualReasoning": "indices visuels courts",
  "searchQueries": [
    "requête Vinted très précise",
    "requête alternative plus large",
    "requête sans coloris"
  ]
}

Règles :
- Si le modèle exact est identifiable, sois précis.
- Si tu n'es pas sûr, propose le modèle le plus probable mais indique une confidence plus basse.
- Ne mets jamais seulement "Sneaker", "Jacket", "T-shirt" comme modèle.
- Pour les chaussures, observe : silhouette, panneaux latéraux, toe box, semelle, branding, languette, matière, coloris.
- Pour les vêtements, observe : coupe, logo, patch, broderie, graphisme, col, poches, zip, matière.
- Les searchQueries doivent être utiles pour Vinted.
- La première searchQuery doit utiliser fullIdentification.
- La deuxième doit être plus tolérante.
- La troisième doit être large mais pertinente.
- Ne pas inventer une collaboration si aucun indice visuel ne la soutient.

Exemple :
Image : adidas noire semelle gum type German Army Trainer
Sortie attendue :
brand: "adidas"
exactModel: "BW Army Decon"
colorway: "Black / Gum"
fullIdentification: "adidas BW Army Decon Black Gum"
searchQueries:
[
  "adidas BW Army Decon Black Gum",
  "adidas BW Army Black Gum",
  "adidas German Army Trainer black gum"
]`;

const MOCK_VISION: FashionVisionResult = {
  category: 'footwear',
  subcategory: 'sneakers',
  dominantItem: 'adidas BW Army Decon Black Gum',
  probableBrand: 'adidas',
  color: 'Black / Gum',
  material: 'leather / suede',
  styleKeywords: [],
  confidence: 0.72,
  sourceConfidence: 0.75,
  inferredModel: 'BW Army Decon',
  dominantColorPrecise: 'Black / Gum',
  itemTypeCanonical: 'sneakers',
  exactModel: 'BW Army Decon',
  colorway: 'Black / Gum',
  fullIdentification: 'adidas BW Army Decon Black Gum',
  visualReasoning: 'silhouette GAT, 3 bandes discrètes, semelle gomme',
  searchQueries: [
    'adidas BW Army Decon Black Gum',
    'adidas BW Army Black Gum',
    'adidas German Army Trainer black gum',
  ],
};

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

function optStr(v: unknown): string | undefined {
  if (v == null) return undefined;
  const s = String(v).trim();
  return s.length > 0 ? s : undefined;
}

function str(v: unknown): string {
  return optStr(v) ?? '';
}

function num(v: unknown, fallback: number): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : fallback;
}

function mapVisionJson(j: Record<string, unknown>): FashionVisionResult {
  const brand = str(j.brand ?? j.probableBrand);
  const exactModel = optStr(j.exactModel);
  const colorway = optStr(j.colorway);
  const fullIdentification = optStr(j.fullIdentification);
  const category = str(j.category);
  const subcategory = str(j.subcategory);
  const material = str(j.material);
  const confidence = num(j.confidence, 0.5);
  const visualReasoning = optStr(j.visualReasoning);

  let searchQueries: string[] | undefined;
  if (Array.isArray(j.searchQueries)) {
    searchQueries = (j.searchQueries as unknown[])
      .map((x) => String(x).trim())
      .filter((s) => s.length > 0);
  }

  const legacyInferred = optStr(j.inferredModel);
  const inferredModel = exactModel ?? legacyInferred;

  const legacyColor = str(j.color);
  const color = legacyColor || colorway || '';

  const legacyDom = optStr(j.dominantColorPrecise);
  const dominantColorPrecise = legacyDom || colorway || (color ? optStr(color) : undefined);

  const dominantItem =
    str(j.dominantItem) ||
    fullIdentification ||
    [brand, exactModel ?? inferredModel, colorway].filter(Boolean).join(' ').trim();

  const styleKeywords = Array.isArray(j.styleKeywords)
    ? (j.styleKeywords as unknown[]).map((x) => String(x))
    : searchQueries && searchQueries.length > 0
      ? [...searchQueries]
      : [];

  const sourceConfidenceRaw = j.sourceConfidence;
  const sourceConfidence = sourceConfidenceRaw != null
    ? num(sourceConfidenceRaw, confidence)
    : undefined;

  const itemTypeCanonical =
    optStr(j.itemTypeCanonical) ||
    (subcategory ? subcategory.toLowerCase() : undefined) ||
    (category ? category.toLowerCase() : undefined);

  return {
    category: category || undefined,
    subcategory: subcategory || undefined,
    dominantItem: dominantItem || undefined,
    probableBrand: brand || undefined,
    color: color || undefined,
    material: material || undefined,
    styleKeywords: styleKeywords.length ? styleKeywords : undefined,
    confidence,
    sourceConfidence,
    inferredEntity: optStr(j.inferredEntity),
    secondaryMarking: optStr(j.secondaryMarking),
    inferredModel,
    dominantColorPrecise,
    itemTypeCanonical,
    exactModel,
    colorway,
    fullIdentification,
    visualReasoning,
    searchQueries: searchQueries?.length ? searchQueries : undefined,
  };
}

export async function analyzeFashionVision(
  imageBase64: string | undefined,
  textQuery: string | undefined
): Promise<FashionVisionResult> {
  const t0 = performance.now();

  if (textQuery && textQuery.trim().length > 0 && !imageBase64) {
    const ms = Math.round(performance.now() - t0);
    console.log(`[PERF] vision=${ms}ms (text-only skip)`);
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
  const userText =
    'Analyse cette image. Réponds UNIQUEMENT avec l\'objet JSON demandé, sans markdown ni texte autour.';

  const completion = await client.chat.completions.create({
    model: process.env.OPENAI_VISION_MODEL ?? 'gpt-4o-mini',
    max_tokens: 800,
    messages: [
      { role: 'system', content: VISION_SYSTEM_PROMPT },
      {
        role: 'user',
        content: [
          { type: 'text', text: userText },
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
    const jsonStr = extractJsonObject(raw) ?? raw.replace(/```json\n?|\n?```/g, '').trim();
    const j = JSON.parse(jsonStr) as Record<string, unknown>;
    parsed = mapVisionJson(j);
  } catch {
    /* keep mock */
  }

  const ms = Math.round(performance.now() - t0);
  console.log(`[PERF] vision=${ms}ms`);
  return parsed;
}
