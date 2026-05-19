# Node + Chromium Playwright (même chemin install/runtime : pas de PLAYWRIGHT_BROWSERS_PATH forcé).
# Railway : Root Directory = backend, builder Docker = ce fichier.
FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
COPY scripts/playwright-postinstall.mjs ./scripts/playwright-postinstall.mjs

ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

# Install deps + télécharge Chromium dans le cache Playwright par défaut (aligné avec chromium.executablePath() au runtime).
RUN npm ci \
  && npx playwright install --with-deps chromium

COPY . .

RUN npm run build \
  && npm prune --omit=dev

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/index.js"]
