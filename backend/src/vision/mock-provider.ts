import type { VisionProvider } from './types.js';
import type { FashionVisionResult } from '../api/types.js';
import type { VisionAnalyzeResult } from './types.js';

const MOCK_QUERIES = [
  'Maison Margiela tabi boots black',
  'black leather split toe boots',
  'Our Legacy wool jacket brown',
  'Lemaire oversized blazer',
  'Margaret Howell linen trousers',
];

function pick<T>(arr: T[]): T {
  return arr[Math.floor(Math.random() * arr.length)] ?? arr[0];
}

export const mockVisionProvider: VisionProvider = {
  async analyzeFashionItem(): Promise<VisionAnalyzeResult> {
    const query = pick(MOCK_QUERIES);
    const [brandPart, ...rest] = query.split(' ');
    const category = rest.some((w) => ['boots', 'jacket', 'blazer', 'trousers'].includes(w))
      ? rest.find((w) => ['boots', 'jacket', 'blazer', 'trousers'].includes(w))
      : 'footwear';
    const color = rest.find((w) =>
      ['black', 'brown', 'white', 'navy', 'grey', 'beige'].includes(w)
    );
    const visionResult: FashionVisionResult = {
      category,
      subcategory: category === 'boots' ? 'ankle boots' : category,
      dominantItem: query,
      probableBrand: brandPart,
      color,
      material: pick(['leather', 'wool', 'linen', 'cotton']),
      styleKeywords: ['minimal', 'luxury'],
      confidence: 0.85,
      sourceConfidence: 0.88,
    };
    return {
      visionResult,
      rawOutput: JSON.stringify(visionResult),
    };
  },
};
