/** Bloqueur Cloudflare / 403 côté Grailed — ne pas traiter comme une erreur serveur globale. */
export class GrailedBlockedError extends Error {
  override readonly name = 'GrailedBlockedError';

  constructor(public readonly reasonCode: string = 'grailed_cloudflare') {
    super(`grailed: blocked (${reasonCode})`);
  }
}
