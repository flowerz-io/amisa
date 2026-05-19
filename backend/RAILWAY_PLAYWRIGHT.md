# Playwright + Chromium sur Railway

## Recommandé : Docker (`Dockerfile`)

1. Dans le service Railway backend, définit **Root Directory** = `backend`.
2. Choisis **Docker** comme méthode de build et pointe vers `Dockerfile`.
3. Pendant le build, `PLAYWRIGHT_BROWSERS_PATH=/ms-playwright` garantit des chemins stables au runtime (voir logs `[PLAYWRIGHT_READY]`).

Le `postinstall` (`scripts/playwright-postinstall.mjs`) détecte `/.dockerenv` et exécute :

`npx playwright install --with-deps chromium`

## Nixpacks (sans Dockerfile)

Si le service utilise encore Nixpacks, `nixpacks.toml` enchaîne `npm ci`, `npx playwright install --with-deps chromium`, puis `npm run build`.

### Commande de build personnalisée

Sur Railway : **Build Command** :

```bash
npm ci && npx playwright install --with-deps chromium && npm run build
```

(équiv. script `railway-release` dans `package.json`.)

## Développement local

Par défaut le `postinstall` **ignore** Chromium (vite `npm ci` / pas de téléchargement lourd). Pour forcer l’installation locale :

```bash
PLAYWRIGHT_POSTINSTALL_FORCE=1 npm ci
```

Désactivation explicite : `SKIP_PLAYWRIGHT_INSTALL=1`.
