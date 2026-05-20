# Variables d’environnement (backend Amisa — **Vinted uniquement**)

Les secrets ne doivent **pas** être commités. Sur Railway, ne définir que ce qui est nécessaire.

## Obligatoire pour la recherche Vinted

| Variable | Description |
|----------|-------------|
| `VINTED_ENABLED` | Doit valoir exactement `true` (sinon le catalogue Vinted est refusé). |
| `PORT` | Port d’écoute (souvent fourni par la plateforme, défaut local `3000`). |

## Vision / génération de requêtes

Selon `VISION_PROVIDER` dans `config` :

| Variable | Description |
|----------|-------------|
| `VISION_PROVIDER` | Fournisseur d’analyse image (voir `src/config.ts`). |
| `OPENAI_API_KEY` | Si vision ou requêtes passent par OpenAI. |
| `GEMINI_API_KEY` | Si vision utilise Gemini. |

## Vinted — accès catalogue

| Variable | Description |
|----------|-------------|
| `VINTED_ACCESS_TOKEN` | Optionnel — Bearer session mobile ; sinon Playwright (plus lent, sensible au blocage). |
| `VINTED_API_BASE` | Optionnel — défaut `https://www.vinted.fr/api/v2`. |
| `VINTED_SCRAPER_PER_PAGE` | Optionnel — taille de page catalogue (défaut `24`). |

## Limites

| Variable | Description |
|----------|-------------|
| `MAX_RESULTS_PER_SEARCH` | Plafond global après fusion (défaut `100`). |

## Développement

| Variable | Description |
|----------|-------------|
| `USE_MOCK` / `MOCK_MODE` | Si `true`, renvoie des listings factices sans appeler Vinted. |
| `DEBUG_PROVIDER_ROUTE` | Mettre `0` pour désactiver `GET /debug-vinted`. |

## Variables Railway **à retirer** (héritage multi-marketplaces)

`EBAY_*`, `DEPOP_*`, `GRAILED_*`, `LEBONCOIN_*` ne sont plus lues par ce backend.
