import { GoogleGenerativeAI, SchemaType } from '@google/generative-ai';
import type { VisionProvider, VisionAnalyzeResult } from './types.js';
import type { FashionVisionResult } from '../api/types.js';

// ---------------------------------------------------------------------------
// Prompt — identique à OpenAI, adapté Gemini (systemInstruction séparé).
// ---------------------------------------------------------------------------

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

16. Ne multiplie pas les synonymes. Pas de texte long. Pas de phrases libres type publicité.

category doit être l'une de ces valeurs exactes si identifiable : footwear, outerwear, tops, bottoms, bags, accessories.`;

const VISION_USER_PROMPT =
  'Analyse l\'image. Retourne UNIQUEMENT un JSON valide conforme au schéma strict.\n\nRappel : valeurs courtes, structurées ; null si incertain ; pas de search query libre.';

// ---------------------------------------------------------------------------
// Schéma de réponse structurée Gemini.
// ---------------------------------------------------------------------------

const GEMINI_RESPONSE_SCHEMA = {
  type: SchemaType.OBJECT,
  properties: {
    category:             { type: SchemaType.STRING,  nullable: true  },
    subcategory:          { type: SchemaType.STRING,  nullable: true  },
    dominantItem:         { type: SchemaType.STRING,  nullable: true  },
    probableBrand:        { type: SchemaType.STRING,  nullable: true  },
    color:                { type: SchemaType.STRING,  nullable: true  },
    material:             { type: SchemaType.STRING,  nullable: true  },
    styleKeywords:        { type: SchemaType.ARRAY,   items: { type: SchemaType.STRING } },
    confidence:           { type: SchemaType.NUMBER                   },
    sourceConfidence:     { type: SchemaType.NUMBER                   },
    inferredEntity:       { type: SchemaType.STRING,  nullable: true  },
    secondaryMarking:     { type: SchemaType.STRING,  nullable: true  },
    inferredModel:        { type: SchemaType.STRING,  nullable: true  },
    dominantColorPrecise: { type: SchemaType.STRING,  nullable: true  },
    itemTypeCanonical:    { type: SchemaType.STRING,  nullable: true  },
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
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

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

/** Détecte le MIME type depuis les premiers octets encodés en base64. */
function detectMimeType(base64: string): 'image/jpeg' | 'image/png' | 'image/webp' {
  if (base64.startsWith('/9j/'))   return 'image/jpeg';
  if (base64.startsWith('iVBOR')) return 'image/png';
  if (base64.startsWith('UklGR')) return 'image/webp';
  return 'image/jpeg';
}

/**
 * Certaines versions de l'API Gemini peuvent envelopper le JSON dans des
 * backticks markdown. On les retire proprement si nécessaire.
 */
function extractJsonContent(raw: string): string {
  const match = raw.match(/```(?:json)?\s*([\s\S]*?)```/);
  return match ? match[1].trim() : raw.trim();
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

export const geminiVisionProvider: VisionProvider = {
  async analyzeFashionItem(imageBuffer: Buffer): Promise<VisionAnalyzeResult> {
    console.log('[GEMINI_ANALYSIS_START]');

    const apiKey = process.env.GEMINI_API_KEY ?? '';
    const genAI = new GoogleGenerativeAI(apiKey);

    const model = genAI.getGenerativeModel({
      model: 'gemini-2.0-flash',
      systemInstruction: VISION_SYSTEM_PROMPT,
      generationConfig: {
        responseMimeType: 'application/json',
        responseSchema: GEMINI_RESPONSE_SCHEMA as never,
        maxOutputTokens: 1024,
        temperature: 0.1,
      },
    });

    const base64 = imageBuffer.toString('base64');
    const mimeType = detectMimeType(base64);

    const result = await model.generateContent([
      VISION_USER_PROMPT,
      { inlineData: { mimeType, data: base64 } },
    ]);

    const rawContent = result.response.text();
    if (!rawContent) {
      console.log('[GEMINI_ANALYSIS_FAILED] empty_response');
      throw new Error('Gemini Vision returned empty response');
    }

    const content = extractJsonContent(rawContent);

    let parsed: ParsedVision;
    try {
      parsed = JSON.parse(content) as ParsedVision;
    } catch (err) {
      console.log('[GEMINI_ANALYSIS_FAILED] json_parse_error', err);
      throw new Error(`Gemini Vision JSON parse error: ${err}`);
    }

    const visionResult: FashionVisionResult = {
      category:             toUndef(parsed.category),
      subcategory:          toUndef(parsed.subcategory),
      dominantItem:         toUndef(parsed.dominantItem),
      probableBrand:        toUndef(parsed.probableBrand),
      color:                toUndef(parsed.color),
      material:             toUndef(parsed.material),
      styleKeywords:        Array.isArray(parsed.styleKeywords) ? parsed.styleKeywords : [],
      confidence:           parsed.confidence ?? 0,
      sourceConfidence:     parsed.sourceConfidence ?? 0,
      inferredEntity:       toUndef(parsed.inferredEntity),
      secondaryMarking:     toUndef(parsed.secondaryMarking),
      inferredModel:        toUndef(parsed.inferredModel),
      dominantColorPrecise: toUndef(parsed.dominantColorPrecise),
      itemTypeCanonical:    toUndef(parsed.itemTypeCanonical),
    };

    console.log('[GEMINI_ANALYSIS_SUCCESS]', {
      category:    visionResult.category,
      brand:       visionResult.probableBrand,
      confidence:  visionResult.confidence,
    });

    return { visionResult, rawOutput: content };
  },
};
