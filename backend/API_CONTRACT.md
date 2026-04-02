# Contrat API Balibu — JSON exact

Aligné avec les modèles Swift (camelCase). Réponses stables et structurées.

---

## POST /analyze-search

Analyse une image de vêtement via Vision et retourne attributs + requêtes + listings mockés.

### Request

```json
{
  "imageBase64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
```

| Champ       | Type   | Obligatoire | Description                    |
|-------------|--------|-------------|--------------------------------|
| imageBase64 | string | ✓           | Image encodée en base64 (JPEG/PNG) |

### Response 200

```json
{
  "visionResult": {
    "category": "footwear",
    "probableBrand": "Maison Margiela",
    "color": "black",
    "material": "leather",
    "styleKeywords": ["minimal", "luxury"],
    "confidence": 0.92,
    "sourceConfidence": 0.88
  },
  "generatedQueries": [
    "Maison Margiela tabi boots black",
    "black leather split toe boots"
  ],
  "listings": [
    {
      "id": "gr-1",
      "source": "Grailed",
      "title": "Maison Margiela Tabi Ankle Boots",
      "price": 390,
      "currency": "EUR",
      "imageUrl": "https://example.com/full.jpg",
      "thumbnailUrl": "https://example.com/thumb.jpg",
      "listingUrl": "https://grailed.com/listings/gr-1",
      "size": "42",
      "condition": "Very Good"
    }
  ]
}
```

| Champ | Type | Description |
|-------|------|-------------|
| visionResult | object | Résultat Vision structuré |
| visionResult.category | string? | Catégorie (footwear, outerwear, etc.) |
| visionResult.probableBrand | string? | Marque détectée |
| visionResult.color | string? | Couleur principale |
| visionResult.material | string? | Matériau |
| visionResult.styleKeywords | string[]? | Mots-clés style |
| visionResult.confidence | number? | Confiance globale 0–1 |
| visionResult.sourceConfidence | number? | Confiance que l'image est une source e-commerce/fashion 0–1 |
| generatedQueries | string[] | Requêtes générées pour la recherche |
| listings | object[] | Listings mockés (alignés avec queries) |

**Chaque listing :**

| Champ      | Type   | Description                    |
|------------|--------|--------------------------------|
| id         | string | Identifiant unique             |
| source     | string | Marketplace (Grailed, Vinted…) |
| title      | string | Titre de l’annonce             |
| price      | number | Prix (nombre, pas string)      |
| currency   | string? | EUR, GBP, etc.                |
| imageUrl   | string? | URL image complète            |
| thumbnailUrl | string? | URL thumbnail (nouveau)      |
| listingUrl | string? | Lien vers l’annonce          |
| size       | string? | Taille                         |
| condition  | string? | État                           |

### Response 400

```json
{
  "error": "imageBase64 is required and must be a base64 string"
}
```

---

## POST /resolve-shared-url

Résout une URL partagée (Pinterest, Google Images, etc.) et extrait l’image principale.

### Request

```json
{
  "url": "https://www.pinterest.com/pin/123456789/"
}
```

| Champ | Type   | Obligatoire | Description         |
|-------|--------|-------------|---------------------|
| url   | string | ✓           | URL de la page partagée |

### Response 200

```json
{
  "imageBase64": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
```

| Champ       | Type   | Description                         |
|-------------|--------|-------------------------------------|
| imageBase64 | string | Image extraite encodée en base64     |
| sourceUrl?  | string | URL d’origine de l’image (optionnel) |

### Response 400 / 404

```json
{
  "error": "no_image_found",
  "message": "Aucune image trouvée sur cette page"
}
```

---

## Types TypeScript (api/types.ts)

```typescript
// POST /analyze-search
export interface AnalyzeSearchRequest {
  imageBase64: string;
}

export interface FashionVisionResult {
  category?: string;
  probableBrand?: string;
  color?: string;
  material?: string;
  styleKeywords?: string[];
  confidence?: number;
  sourceConfidence?: number;
}

export interface MarketplaceListingDTO {
  id: string;
  source: string;
  title: string;
  price: number;
  currency?: string;
  imageUrl?: string;
  thumbnailUrl?: string;
  listingUrl?: string;
  size?: string;
  condition?: string;
}

export interface AnalyzeSearchResponse {
  visionResult: FashionVisionResult;
  generatedQueries: string[];
  listings: MarketplaceListingDTO[];
}

// POST /resolve-shared-url
export interface ResolveSharedUrlRequest {
  url: string;
}

export interface ResolveSharedUrlResponse {
  imageBase64: string;
  sourceUrl?: string;
}

export interface ResolveSharedUrlErrorResponse {
  error: string;
  message: string;
}
```

---

## Configuration

- **OPENAI_API_KEY** : Si défini, utilise le provider OpenAI Vision. Sinon, utilise le mock provider.
