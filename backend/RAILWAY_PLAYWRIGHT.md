# Playwright + Chromium sur Railway

## Cause fréquente de « chromium absent »

- Variable **`PLAYWRIGHT_BROWSERS_PATH=/ms-playwright`** (ou autre) **en runtime** alors que Chromium a été installé ailleurs **au build** → le chemin attendu n’existe pas.
- **Correctif** : ne pas fixer `PLAYWRIGHT_BROWSERS_PATH` dans les variables Railway, sauf si tu maîtrises le même chemin au **build** et au **run**.

Les builds de ce repo **n’imposent plus** de répertoire custom : Chromium va dans le cache Playwright par défaut (souvent sous `/root/.cache/ms-playwright` dans l’image).

## Docker (`Dockerfile`) — recommandé

1. Service Railway : **Root Directory** = `backend`.
2. Builder **Docker** avec le `Dockerfile` du dépôt.
3. Le `RUN npm ci && npx playwright install --with-deps chromium` garantit le navigateur **dans l’image**.

## Nixpacks (sans Docker)

- `nixpacks.toml` et/ou `railway.json` enchaînent :  
  `npm ci && npx playwright install --with-deps chromium && npm run build`.

## Scripts npm (`package.json`)

| Script | Rôle |
|--------|------|
| `prepare:chromium` | `npx playwright install --with-deps chromium` |
| `build:railway` | `tsc` puis install Chromium (ex. debug local prod) |
| `railway-release` | install Chromium puis `tsc` (ordre build strict) |

## Logs au démarrage

- `[PLAYWRIGHT] chromium ready path=...`
- `[PLAYWRIGHT] chromium missing path=...`

## Développement local

Le `postinstall` évite de tout télécharger par défaut. Forcer :

```bash
PLAYWRIGHT_POSTINSTALL_FORCE=1 npm ci
```

Désactiver : `SKIP_PLAYWRIGHT_INSTALL=1`.
