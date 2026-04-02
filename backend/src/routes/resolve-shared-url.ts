import { FastifyInstance } from 'fastify';
import type {
  ResolveSharedUrlRequest,
  ResolveSharedUrlResponse,
  ResolveSharedUrlErrorResponse,
} from '../api/types.js';
import { load as loadCheerio } from 'cheerio';

/**
 * Résout une URL partagée (Pinterest, Google Images, page web)
 * et extrait l'image principale (og:image, twitter:image, ou première image significative).
 */
export async function resolveSharedUrlRoute(app: FastifyInstance) {
  app.post<{
    Body: ResolveSharedUrlRequest;
    Reply: ResolveSharedUrlResponse | ResolveSharedUrlErrorResponse;
  }>('/resolve-shared-url', async (request, reply) => {
    const body = request.body;

    if (!body?.url || typeof body.url !== 'string') {
      return reply.status(400).send({
        error: 'invalid_request',
        message: 'url is required and must be a string',
      });
    }

    const url = body.url.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return reply.status(400).send({
        error: 'invalid_url',
        message: 'url must be a valid http or https URL',
      });
    }

    try {
      const htmlResponse = await fetch(url, {
        headers: {
          'User-Agent':
            'Mozilla/5.0 (compatible; Balibu/1.0; +https://balibu.app)',
        },
        redirect: 'follow',
      });

      if (!htmlResponse.ok) {
        return reply.status(404).send({
          error: 'page_unavailable',
          message: `Could not fetch page: ${htmlResponse.status}`,
        });
      }

      const html = await htmlResponse.text();
      const $ = loadCheerio(html);

      let imageUrl: string | null = null;

      const ogImage = $('meta[property="og:image"]').attr('content');
      const twitterImage = $('meta[name="twitter:image"]').attr('content');
      const twitterImageContent = $('meta[property="twitter:image"]').attr('content');

      if (ogImage) {
        imageUrl = resolveUrl(ogImage, url);
      } else if (twitterImage) {
        imageUrl = resolveUrl(twitterImage, url);
      } else if (twitterImageContent) {
        imageUrl = resolveUrl(twitterImageContent, url);
      }

      if (!imageUrl) {
        const firstImg = $('img[src]').first().attr('src');
        if (firstImg) {
          const resolved = resolveUrl(firstImg, url);
          imageUrl = resolved;
        }
      }

      if (!imageUrl) {
        return reply.status(404).send({
          error: 'no_image_found',
          message: 'Aucune image trouvée sur cette page',
        });
      }

      const imageResponse = await fetch(imageUrl);
      if (!imageResponse.ok) {
        return reply.status(404).send({
          error: 'image_unavailable',
          message: 'Impossible de télécharger l\'image',
        });
      }

      const imageBuffer = Buffer.from(await imageResponse.arrayBuffer());
      const imageBase64 = imageBuffer.toString('base64');

      if (imageBase64.length === 0) {
        return reply.status(404).send({
          error: 'invalid_image',
          message: 'L\'image récupérée est vide',
        });
      }

      const response: ResolveSharedUrlResponse = {
        imageBase64,
        sourceUrl: imageUrl,
      };

      return reply.send(response);
    } catch (err) {
      request.log.error(err, 'resolve-shared-url failed');
      return reply.status(500).send({
        error: 'server_error',
        message: 'Erreur lors de la résolution de l\'URL',
      });
    }
  });
}

function resolveUrl(href: string, base: string): string {
  const trimmed = href.trim();
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  if (trimmed.startsWith('//')) {
    return `https:${trimmed}`;
  }
  try {
    const baseUrl = new URL(base);
    return new URL(trimmed, baseUrl).href;
  } catch {
    return trimmed;
  }
}
