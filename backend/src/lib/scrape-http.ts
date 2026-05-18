/**
 * En-têtes HTTP orientés navigateur pour endpoints publics / scraping léger.
 */
export function browserLikeHeaders(
  extra?: Record<string, string>
): Record<string, string> {
  const ua =
    process.env.SCRAPER_USER_AGENT?.trim() ||
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  return {
    'User-Agent': ua,
    Accept: 'application/json, text/html, application/xhtml+xml, */*;q=0.8',
    'Accept-Language': 'fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'no-cache',
    ...extra,
  };
}

export async function fetchText(
  url: string,
  init?: RequestInit
): Promise<{ status: number; text: string }> {
  const res = await fetch(url, {
    ...init,
    headers: {
      ...browserLikeHeaders(),
      ...(init?.headers as Record<string, string> | undefined),
    },
  });
  const text = await res.text();
  return { status: res.status, text };
}
