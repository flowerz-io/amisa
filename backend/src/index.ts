import 'dotenv/config';

import { existsSync } from 'node:fs';
import Fastify from 'fastify';
import cors from '@fastify/cors';
import { chromium } from 'playwright';
import {
  visionProviderName,
  logVisionProviderDiagnostic,
} from './config.js';
import { analyzeSearchRoute } from './routes/analyze-search.js';
import { resolveSharedUrlRoute } from './routes/resolve-shared-url.js';
import { vintedListingsRoute } from './routes/vinted-listings.js';
import { grailedListingsRoute } from './routes/grailed-listings.js';
import { ebayListingsRoute } from './routes/ebay-listings.js';
import { leBonCoinListingsRoute } from './routes/leboncoin-listings.js';
import { searchMoreRoute } from './routes/search-more.js';
import { PROVIDERS_ENABLED } from './providers-config.js';

logVisionProviderDiagnostic();
const grailedBrowserPath = chromium.executablePath();
console.log(
  `[GRAILED_BROWSER_READY] ${existsSync(grailedBrowserPath) ? 'yes' : 'no'} path=${grailedBrowserPath}`
);
console.log(
  `[LEBONCOIN_BROWSER_READY] ${existsSync(grailedBrowserPath) ? 'yes' : 'no'} path=${grailedBrowserPath}`
);
console.log('[PROVIDERS_ENABLED]', PROVIDERS_ENABLED);

const app = Fastify({ logger: true });

await app.register(cors, { origin: true });

app.register(analyzeSearchRoute, { prefix: '/' });
app.register(resolveSharedUrlRoute, { prefix: '/' });
app.register(vintedListingsRoute, { prefix: '/' });
app.register(grailedListingsRoute, { prefix: '/' });
app.register(ebayListingsRoute, { prefix: '/' });
app.register(leBonCoinListingsRoute, { prefix: '/' });
app.register(searchMoreRoute, { prefix: '/' });

const port = parseInt(process.env.PORT ?? '3000', 10);
await app.listen({ port, host: '0.0.0.0' });

console.log(`Balibu API running on http://localhost:${port}`);
console.log(`VISION_PROVIDER=${visionProviderName}`);
