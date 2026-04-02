import type { StructuredFashionQuery } from './types.js';
import { mockConnector } from './mock-connector.js';

export async function searchMarketplaces(
  query: StructuredFashionQuery
): Promise<Array<{ id: string; title: string; price: string; source: string; url: string; imageUrl?: string; condition?: string }>> {
  const results = await mockConnector.search(query);
  return results;
}
