FROM mcr.microsoft.com/playwright:v1.59.1-jammy

WORKDIR /app

# Browsers déjà présents dans l'image Playwright officielle.
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build && npm prune --omit=dev

ENV NODE_ENV=production

EXPOSE 3000

CMD ["npm", "run", "start"]
