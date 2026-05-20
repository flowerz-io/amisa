import 'dotenv/config';

import Fastify from 'fastify';
import cors from '@fastify/cors';
import { logVisionProviderDiagnostic } from './config.js';
import { logProviderEnvironmentDiagnostics } from './lib/provider-env.js';
import { logPlaywrightReadinessAtStartup } from './lib/playwright-browser.js';
import { analyzeSearchRoute } from './routes/analyze-search.js';
import { debugProviderRoute } from './routes/debug-provider.js';
import { debugEbayRoute } from './routes/debug-ebay.js';
import { resolveSharedUrlRoute } from './routes/resolve-shared-url.js';
import { vintedListingsRoute } from './routes/vinted-listings.js';
import { grailedListingsRoute } from './routes/grailed-listings.js';
import { ebayListingsRoute } from './routes/ebay-listings.js';
import { leBonCoinListingsRoute } from './routes/leboncoin-listings.js';
import { depopListingsRoute } from './routes/depop-listings.js';
import { searchMoreRoute } from './routes/search-more.js';
import { searchSessionsRoute } from './routes/search-sessions.js';
import { PROVIDERS_ENABLED } from './providers-config.js';

logVisionProviderDiagnostic();
console.log('[PROVIDERS_ENABLED]', PROVIDERS_ENABLED);
logProviderEnvironmentDiagnostics();
await logPlaywrightReadinessAtStartup();

const app = Fastify({ logger: true });

app.addHook('onRequest', async (request, _reply) => {
  console.log(`[REQ] ${request.method} ${request.url}`);
});

await app.register(cors, { origin: true });

app.get('/health', async () => ({ ok: true, service: 'amisa-backend' }));

app.register(analyzeSearchRoute, { prefix: '/' });
app.register(searchSessionsRoute, { prefix: '/' });
app.register(resolveSharedUrlRoute, { prefix: '/' });
app.register(vintedListingsRoute, { prefix: '/' });
app.register(grailedListingsRoute, { prefix: '/' });
app.register(ebayListingsRoute, { prefix: '/' });
app.register(leBonCoinListingsRoute, { prefix: '/' });
app.register(depopListingsRoute, { prefix: '/' });
app.register(searchMoreRoute, { prefix: '/' });
app.register(debugProviderRoute, { prefix: '/' });
app.register(debugEbayRoute, { prefix: '/' });

const port = parseInt(process.env.PORT ?? '3000', 10);
console.log('Amisa API running');
await app.listen({ port, host: '0.0.0.0' });

console.log('[Amisa API] base ready');
console.log(
  '[Amisa API] routes: GET /health, GET /debug-provider, GET /debug-ebay, POST /analyze-search, GET /search-sessions/:sessionId, POST /resolve-shared-url, POST /search-sessions'
);
console.log(`[Amisa API] listening on http://localhost:${port}`);
