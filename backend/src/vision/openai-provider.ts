import OpenAI from 'openai';
import type { VisionProvider } from './types.js';
import type { FashionVisionResult } from '../api/types.js';
import type { VisionAnalyzeResult } from './types.js';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY ?? '',
});

const VISION_SYSTEM_PROMPT = `Tu analyses une image pour identifier UNIQUEMENT l'item fashion principal et remplir un JSON STRUCTURÉ.
Tu ne rédiges JAMAIS de phrase marketing, JAMAIS de search query libre, JAMAIS de synonymes ni de variations créatives.

OBJECTIF DES CHAMPS :
Les champs servent au backend à construire une requête de recherche déterministe. Chaque valeur doit être courte, stable et factuelle.

RÈGLES GÉNÉRALES :
1. OBJET PRINCIPAL : item dominant = surface visuelle + centralité + netteté. Ignorer décor, fond, accessoires non portés.

2. CHAUSSURES : Si une chaussure est l'objet principal, category = "footwear".

3. probableBrand : uniquement si marque lisible (logo, étiquette) OU reconnaissance visuelle très forte. Sinon null. Ne pas deviner.

4. inferredEntity : équipe / club / franchise / univers sportif ou culturel identifiable par logo ou texte (ex: Mets, Lakers, NBA). Sinon null.

5. secondaryMarking : collaboration, collection capsule, institution, texte secondaire sur l'item (ex: MoMA, Supreme x …). Sinon null.

6. inferredModel : nom de modèle SI reconnaissance visuelle forte ou logo modèle (ex: Detroit Jacket, Boston, 991, 59Fifty). Sinon null — ne pas inventer.

7. dominantColorPrecise : UNE SEULE couleur simple couvrant ~80 % de la surface de l'objet principal (pas le fond). Si incertain, null.

8. color : secours / approximation si dominantColorPrecise impossible ; sinon aligné ou null.

9. itemTypeCanonical : UN mot ou deux max pour le type d'objet (jacket, cap, clog, sneaker, tote bag) pour désambiguïser quand le modèle ne le contient pas. Sinon null.

10. subcategory : type concret (ankle boots, baseball cap, etc.) si identifiable.

11. dominantItem : courte description factuelle de l'objet (max ~8 mots), PAS une requête de recherche, pas une liste de synonymes.

12. material : seulement si fiable visuellement, sinon null.

13. styleKeywords : 0 à 4 mots-clés visuels factuels max ; sinon [].

14. NON-FASHION : si pas d'item fashion clair : category = null, sous-champs nulls, confidence et sourceConfidence < 0.3.

15. confidence / sourceConfidence : entre 0 et 1.

16. Ne multiplie pas les synonymes. Pas de texte long. Pas de phrases libres type publicité.`;

const VISION_USER_PROMPT = `Analyse l'image. Retourne UNIQUEMENT un JSON valide conforme au schéma strict.

Rappel : valeurs courtes, structurées ; null si incertain ; pas de search query libre.`;

const VISION_JSON_SCHEMA = {
  type: 'object' as const,
  properties: {
    category: {
      anyOf: [
        {
          type: 'string',
          enum: ['footwear', 'outerwear', 'tops', 'bottoms', 'bags', 'accessories'],
        },
        { type: 'null' },
      ],
      description: "Catégorie de l'item principal, ou null si non fashion",
    },
    subcategory: {
      type: ['string', 'null'],
      description: 'Sous-type concret ou null',
    },
    dominantItem: {
      type: ['string', 'null'],
      description: 'Description factuelle courte, pas une requête de recherche',
    },
    probableBrand: {
      type: ['string', 'null'],
      description: 'Marque seulement si lisible ou très reconnaissable',
    },
    color: {
      type: ['string', 'null'],
      description: 'Couleur secours si besoin',
    },
    material: {
      type: ['string', 'null'],
      description: 'Matière si fiable',
    },
    styleKeywords: {
      type: 'array',
      items: { type: 'string' },
      description: '0 à 4 mots-clés',
    },
    confidence: {
      type: 'number',
      description: 'Entre 0 et 1',
    },
    sourceConfidence: {
      type: 'number',
      description: 'Entre 0 et 1',
    },
    inferredEntity: {
      type: ['string', 'null'],
      description: 'Équipe, club, franchise si logo/texte clair',
    },
    secondaryMarking: {
      type: ['string', 'null'],
      description: 'Collab, MoMA, texte secondaire utile',
    },
    inferredModel: {
      type: ['string', 'null'],
      description: 'Modèle si fortement identifiable, sinon null',
    },
    dominantColorPrecise: {
      type: ['string', 'null'],
      description: 'Une couleur simple dominante sur ~80% de l’objet',
    },
    itemTypeCanonical: {
      type: ['string', 'null'],
      description: 'Type court: jacket, cap, sneaker, clog, etc.',
    },
  },
  required: [
    'category',
    'subcategory',
    'dominantItem',
    'probableBrand',
    'color',
    'material',
    'styleKeywords',
    'confidence',
    'sourceConfidence',
    'inferredEntity',
    'secondaryMarking',
    'inferredModel',
    'dominantColorPrecise',
    'itemTypeCanonical',
  ],
  additionalProperties: false,
};

type ParsedVision = {
  category: string | null;
  subcategory: string | null;
  dominantItem: string | null;
  probableBrand: string | null;
  color: string | null;
  material: string | null;
  styleKeywords: string[];
  confidence: number;
  sourceConfidence: number;
  inferredEntity: string | null;
  secondaryMarking: string | null;
  inferredModel: string | null;
  dominantColorPrecise: string | null;
  itemTypeCanonical: string | null;
};

function toUndef(s: string | null | undefined): string | undefined {
  if (s == null || s === '') return undefined;
  return s;
}

export const openaiVisionProvider: VisionProvider = {
  async analyzeFashionItem(imageBuffer: Buffer): Promise<VisionAnalyzeResult> {
    const base64 = imageBuffer.toString('base64');
    const mimeType = base64.startsWith('/9j/') ? 'image/jpeg' : 'image/png';

    const response = await openai.chat.completions.create({
      model: 'gpt-4o',
      max_tokens: 1024,
      messages: [
        { role: 'system', content: VISION_SYSTEM_PROMPT },
        {
          role: 'user',
          content: [
            { type: 'text', text: VISION_USER_PROMPT },
            {
              type: 'image_url',
              image_url: {
                url: `data:${mimeType};base64,${base64}`,
                detail: 'high',
              },
            },
          ],
        },
      ],
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'fashion_vision_result',
          strict: true,
          schema: VISION_JSON_SCHEMA,
        },
      },
    });

    const content = response.choices[0]?.message?.content;
    if (!content) {
      throw new Error('OpenAI Vision returned empty response');
    }

    const parsed = JSON.parse(content) as ParsedVision;

    const visionResult: FashionVisionResult = {
      category: toUndef(parsed.category),
      subcategory: toUndef(parsed.subcategory),
      dominantItem: toUndef(parsed.dominantItem),
      probableBrand: toUndef(parsed.probableBrand),
      color: toUndef(parsed.color),
      material: toUndef(parsed.material),
      styleKeywords: parsed.styleKeywords,
      confidence: parsed.confidence,
      sourceConfidence: parsed.sourceConfidence,
      inferredEntity: toUndef(parsed.inferredEntity),
      secondaryMarking: toUndef(parsed.secondaryMarking),
      inferredModel: toUndef(parsed.inferredModel),
      dominantColorPrecise: toUndef(parsed.dominantColorPrecise),
      itemTypeCanonical: toUndef(parsed.itemTypeCanonical),
    };

    return {
      visionResult,
      rawOutput: content,
    };
  },
};
