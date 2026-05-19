#!/usr/bin/env node
/**
 * Installe Chromium + dépendances OS quand pertinent (Railway / CI / Docker demandé explicitement).
 * En dev local sans variable d’activation : aucun téléchargement (évite sudo / lenteur).
 */
import { spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';

const skip =
  process.env.SKIP_PLAYWRIGHT_INSTALL?.trim().toLowerCase() === '1' ||
  process.env.SKIP_PLAYWRIGHT_INSTALL?.trim().toLowerCase() === 'true';

if (skip) {
  console.log(
    '[playwright-postinstall] skipped (SKIP_PLAYWRIGHT_INSTALL=1)'
  );
  process.exit(0);
}

const force =
  process.env.PLAYWRIGHT_POSTINSTALL_FORCE?.trim() === '1' ||
  process.env.PLAYWRIGHT_POSTINSTALL_FORCE?.trim().toLowerCase() === 'true';

const railway = Boolean(
  process.env.RAILWAY_ENVIRONMENT_NAME ||
    process.env.RAILWAY_ENVIRONMENT ||
    process.env.RAILWAY_PROJECT_ID
);
const docker = existsSync('/.dockerenv');

const ghActions = Boolean(process.env.GITHUB_ACTIONS);
const ci = Boolean(process.env.CI);

/** Activer hors Docker uniquement Railway / CI / FORCE (évite tout postinstall brutal en local). */
if (!docker && !railway && !ghActions && !ci && !force) {
  console.log(
    '[playwright-postinstall] skipped locally. Dockerfile / Railway with Docker runs `playwright install --with-deps`. Or: PLAYWRIGHT_POSTINSTALL_FORCE=1 npm ci'
  );
  process.exit(0);
}

console.log(
  '[playwright-postinstall] npx playwright install --with-deps chromium'
);
const r = spawnSync(
  'npx',
  ['playwright', 'install', '--with-deps', 'chromium'],
  { stdio: 'inherit', shell: false }
);
process.exit(r.status === 0 ? 0 : r.status ?? 1);
