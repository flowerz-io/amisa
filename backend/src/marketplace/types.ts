export interface StructuredFashionQuery {
  query: string;
  category?: string;
  subcategory?: string;
  brand?: string;
  color?: string;
  material?: string;
}

export interface MarketplaceListing {
  id: string;
  title: string;
  price: string;
  source: string;
  url: string;
  imageUrl?: string;
  condition?: string;
}

export interface MarketplaceConnector {
  search(query: StructuredFashionQuery): Promise<MarketplaceListing[]>;
}
