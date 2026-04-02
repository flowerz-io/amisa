import OpenAI from 'openai';
import type { VisionProvider } from './types.js';
import type { FashionVisionResult } from '../api/types.js';
import type { VisionAnalyzeResult } from './types.js';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY ?? '',
});

const VISION_SYSTEM_PROMPT = `Tu analyses une image pour identifier UNIQUEMENT l'item fashion principal. Analyse visuelle stricte — pas de génération de requêtes.

RÈGLES STRICTES :

1. OBJET PRINCIPAL : Déterminer l'item fashion dominant par : surface visuelle occupée + centralité + netteté. Ignorer décor, fond, accessoires secondaires, autres vêtements.

2. CHAUSSURES : Si une chaussure (botte, sneaker, escarpin, mocassin, etc.) est l'objet principal visible, category DOIT être "footwear". Ne JAMAIS renvoyer outerwear, tops ou bottoms si l'unique objet dominant est une chaussure.

3. MARQUE : probableBrand = null sauf si la marque est explicitement lisible (logo visible, étiquette reconnaissable) ou hautement reconnaissable. Ne jamais deviner.

4. MATIÈRE : material = null sauf si identifiable de façon visuellement fiable (texture, aspect). Ne jamais inventer.

5. COULEUR : si incertain, retourner null. Ne pas inventer.

6. CATEGORY INCERTAINE : Si doute entre plusieurs classes, choisir la plus visible et concrète. Ne jamais inventer une classe hors de l'enum.

7. SUBCATEGORY : retourner une sous-catégorie simple et concrète si identifiable, sinon null.

8. dominantItem : courte phrase décrivant l'item principal si identifiable, sinon null.

9. NON-FASHION : Si l’image ne contient PAS un item fashion clair (vêtements, chaussures, sacs, accessoires portables), retourner category = null, subcategory = null, dominantItem = null, confidence < 0.3 et sourceConfidence < 0.3.

10. styleKeywords : tableau de 0 à 4 mots-clés visuels max. Si rien de fiable, retourner [].

11. confidence et sourceConfidence : nombres entre 0 et 1.

12. Si plusieurs items fashion visibles, choisir celui le plus proche du centre ET le plus distinct visuellement.`;

const VISION_USER_PROMPT = `Analyse l'image. Retourne UNIQUEMENT un JSON valide conforme au schéma.

Champs attendus :
- category : footwear | outerwear | tops | bottoms | bags | accessories
- subcategory : string ou null
- dominantItem : string ou null
- probableBrand : string ou null
- color : string ou null
- material : string ou null
- styleKeywords : tableau de strings
- confidence : number
- sourceConfidence : number`;

const VISION_JSON_SCHEMA = {
  type: 'object' as const,
  properties: {
    category: {
      type: 'string',
      enum: ['footwear', 'outerwear', 'tops', 'bottoms', 'bags', 'accessories'],
      description: "Catégorie de l'item principal",
    },
    subcategory: {
      type: ['string', 'null'],
      description: 'Sous-catégorie simple : boots, sneakers, blazer, coat, t-shirt, trousers, etc.',
    },
    dominantItem: {
      type: ['string', 'null'],
      description: "Description courte de l'item principal",
    },
    probableBrand: {
      type: ['string', 'null'],
      description: 'Marque seulement si explicitement lisible ou hautement reconnaissable, sinon null',
    },
    color: {
      type: ['string', 'null'],
      description: 'Couleur dominante la plus probable, ou null si incertain',
    },
    material: {
      type: ['string', 'null'],
      description: 'Matériau seulement si visuellement fiable, sinon null',
    },
    styleKeywords: {
      type: 'array',
      items: { type: 'string' },
      description: '0 à 4 mots-clés visuels maximum',
    },
    confidence: {
      type: 'number',
      description: 'Confiance globale entre 0 et 1',
    },
    sourceConfidence: {
      type: 'number',
      description: "Confiance que l'objet principal est bien un item fashion, entre 0 et 1",
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
  ],
  additionalProperties: false,
};

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

    const parsed = JSON.parse(content) as {
      category: string;
      subcategory: string | null;
      dominantItem: string | null;
      probableBrand: string | null;
      color: string | null;
      material: string | null;
      styleKeywords: string[];
      confidence: number;
      sourceConfidence: number;
    };

    const visionResult: FashionVisionResult = {
      category: parsed.category,
      subcategory: parsed.subcategory ?? undefined,
      dominantItem: parsed.dominantItem ?? undefined,
      probableBrand: parsed.probableBrand ?? undefined,
      color: parsed.color ?? undefined,
      material: parsed.material ?? undefined,
      styleKeywords: parsed.styleKeywords,
      confidence: parsed.confidence,
      sourceConfidence: parsed.sourceConfidence,
    };

    return {
      visionResult,
      rawOutput: content,
    };
  },
};