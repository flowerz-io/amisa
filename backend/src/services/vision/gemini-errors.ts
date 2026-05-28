export class GeminiVisionError extends Error {
  readonly code: string;
  readonly httpStatus?: number;

  constructor(code: string, message: string, httpStatus?: number) {
    super(message);
    this.name = 'GeminiVisionError';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export function isGeminiQuotaError(status: number, body: string): boolean {
  if (status === 429) return true;
  const lower = body.toLowerCase();
  return (
    lower.includes('quota') ||
    lower.includes('rate limit') ||
    lower.includes('resource_exhausted') ||
    lower.includes('too many requests')
  );
}

export function geminiErrorFromHttp(status: number, body: string): GeminiVisionError {
  if (isGeminiQuotaError(status, body)) {
    return new GeminiVisionError(
      'gemini_quota_exceeded',
      'Gemini quota exceeded. Check billing or API limits.',
      429
    );
  }
  return new GeminiVisionError(
    'gemini_vision_failed',
    `Gemini vision failed (HTTP ${status}).`,
    status >= 400 && status < 600 ? status : 502
  );
}
