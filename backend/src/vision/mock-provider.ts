import type { VisionProvider } from './types.js';
import type { FashionVisionResult } from '../api/types.js';
import type { VisionAnalyzeResult } from './types.js';

const MOCK_SAMPLES: FashionVisionResult[] = [
  {
    category: 'footwear',
    subcategory: 'ankle boots',
    dominantItem: 'Black leather tabi ankle boots',
    probableBrand: 'Maison Margiela',
    color: 'black',
    dominantColorPrecise: 'black',
    material: 'leather',
    styleKeywords: ['tabi', 'split toe'],
    confidence: 0.85,
    sourceConfidence: 0.88,
    inferredEntity: undefined,
    secondaryMarking: undefined,
    inferredModel: 'Tabi',
    itemTypeCanonical: 'boots',
  },
  {
    category: 'outerwear',
    subcategory: 'jacket',
    dominantItem: 'Wool overshirt',
    probableBrand: 'Our Legacy',
    color: 'brown',
    dominantColorPrecise: 'brown',
    material: 'wool',
    styleKeywords: ['minimal'],
    confidence: 0.82,
    sourceConfidence: 0.86,
    inferredModel: undefined,
    itemTypeCanonical: 'jacket',
  },
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)] ?? arr[0];
}

export const mockVisionProvider: VisionProvider = {
  async analyzeFashionItem(): Promise<VisionAnalyzeResult> {
    const visionResult = pick(MOCK_SAMPLES);
    return {
      visionResult,
      rawOutput: JSON.stringify(visionResult),
    };
  },
};
