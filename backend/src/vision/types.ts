import type { FashionVisionResult } from '../api/types.js';

/** Résultat d'une analyse Vision pour l'API (aligné Swift). */
export type { FashionVisionResult };

/** Résultat d'analyse (rawOutput pour diagnostic uniquement). */
export interface VisionAnalyzeResult {
  visionResult: FashionVisionResult;
  rawOutput?: string;
}

/** Le provider Vision retourne l'analyse visuelle structurée + rawOutput si DEBUG. */
export interface VisionProvider {
  analyzeFashionItem(imageData: Buffer): Promise<VisionAnalyzeResult>;
}
