import type { MarketplaceConnector, MarketplaceListing, StructuredFashionQuery } from './types.js';
import { mockSearchResults } from '../mock/listings.js';

export const mockConnector: MarketplaceConnector = {
  async search(_query: StructuredFashionQuery): Promise<MarketplaceListing[]> {
    return [...mockSearchResults];
  },
};
