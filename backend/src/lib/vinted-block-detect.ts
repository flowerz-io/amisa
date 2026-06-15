/** Détecte page Vinted bloquée, captcha ou réponse catalogue invalide. */

export type VintedBlockReason =
  | 'http_403'
  | 'api_code_100'
  | 'captcha'
  | 'cloudflare'
  | 'datadome'
  | 'empty_html'
  | 'invalid_json';

const CAPTCHA_MARKERS = [
  'captcha',
  'datadome',
  'cf-challenge',
  'challenge-platform',
  'just a moment',
  'vérifiez que vous êtes humain',
  'access denied',
  'accès refusé',
];

export function detectVintedBlockFromHtml(html: string): VintedBlockReason | null {
  const lower = html.toLowerCase();
  if (lower.includes('datadome')) return 'datadome';
  if (lower.includes('cf-challenge') || lower.includes('just a moment')) {
    return 'cloudflare';
  }
  for (const m of CAPTCHA_MARKERS) {
    if (lower.includes(m)) return 'captcha';
  }
  return null;
}

export function detectVintedBlockFromApiPayload(
  status: number,
  text: string
): VintedBlockReason | null {
  if (status === 403) return 'http_403';
  const trimmed = text.trim();
  if (!trimmed.startsWith('{')) {
    const htmlBlock = detectVintedBlockFromHtml(trimmed);
    if (htmlBlock) return htmlBlock;
    return 'invalid_json';
  }
  try {
    const data = JSON.parse(trimmed) as Record<string, unknown>;
    if (data.code === 100) return 'api_code_100';
  } catch {
    return 'invalid_json';
  }
  return null;
}

export function isRetryableVintedBlock(reason: VintedBlockReason | null): boolean {
  if (!reason) return false;
  return reason !== 'empty_html';
}
