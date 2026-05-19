# Image Node + installation explicite Chromium Playwright (alignée sur la version npm du service).
# Railway : définir le répertoire racine du service sur `backend` et ce Dockerfile comme build file.
FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package.json package-lock.json ./
COPY scripts/playwright-postinstall.mjs ./scripts/playwright-postinstall.mjs

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=0

RUN npm ci

COPY . .

RUN npm run build \
  && npm prune --omit=dev

ENV NODE_ENV=production
EXPOSE 3000

CMD ["node", "dist/index.js"]
