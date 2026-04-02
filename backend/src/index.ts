import 'dotenv/config';

import Fastify from 'fastify';
import cors from '@fastify/cors';
import {
  visionProviderName,
  logVisionProviderDiagnostic,
} from './config.js';
import { analyzeSearchRoute } from './routes/analyze-search.js';
import { resolveSharedUrlRoute } from './routes/resolve-shared-url.js';

logVisionProviderDiagnostic();

const app = Fastify({ logger: true });

await app.register(cors, { origin: true });

app.register(analyzeSearchRoute, { prefix: '/' });
app.register(resolveSharedUrlRoute, { prefix: '/' });

const port = parseInt(process.env.PORT ?? '3000', 10);
await app.listen({ port, host: '0.0.0.0' });

console.log(`Balibu API running on http://localhost:${port}`);
console.log(`VISION_PROVIDER=${visionProviderName}`);
