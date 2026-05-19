/** Erreur scraping / HTTP explicite pour les providers non-eBay. */
export class ProviderScrapeError extends Error {
  constructor(
    message: string,
    public readonly httpStatus?: number,
    public readonly blocked403 = false
  ) {
    super(message);
    this.name = 'ProviderScrapeError';
  }
}
