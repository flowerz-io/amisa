# Balibu MVP — Architecture

## Vue d'ensemble

Balibu est une app iOS qui permet de partager une image depuis n'importe quelle app, puis de rechercher des vêtements similaires sur des marketplaces de seconde main via analyse vision + requêtes structurées.

---

## ÉTAPE 1 — Architecture MVP

### 1.1 Flow principal

```
[App externe] → Share → [Share Extension] → App Group → [App principale] → [Backend] → [Résultats]
```

1. **Share Extension** : Reçoit l'image via NSExtensionContext, sauvegarde dans App Group, ouvre l'app principale via URL scheme
2. **App principale** : Lit le payload partagé, affiche SharedImportReview, envoie image au backend
3. **Backend** : Vision Provider → attributs fashion → requêtes → connecteurs marketplace → résultats normalisés
4. **App** : Affiche résultats, historique local

### 1.2 Architecture iOS (MVVM simple)

```
Balibu/
├── App/
│   ├── BalibuApp.swift          # Point d'entrée
│   └── AppRouter.swift         # Navigation + deep linking
├── Core/
│   ├── DesignSystem/           # Couleurs, typo, composants
│   ├── Utils/                  # Helpers
│   ├── Networking/             # Configuration réseau
│   └── Storage/                # Abstraction App Group
├── Models/                     # Modèles partagés
├── Services/                   # Couche métier
├── Features/
│   ├── Home/
│   ├── SharedImport/
│   ├── Results/
│   └── SearchHistory/
└── Extensions/                 # Extensions Swift

BalibuShareExtension/
├── ShareViewController.swift   # UIKit, gère NSExtensionContext
├── ShareItemExtractor.swift    # Extraction image/vidéo
└── ShareExtensionCoordinator.swift  # App Group + ouverture app
```

### 1.3 Architecture Backend (TypeScript)

```
Backend/
├── src/
│   ├── index.ts
│   ├── routes/
│   │   └── analyze-search.ts
│   ├── providers/
│   │   └── vision/
│   │       ├── VisionProvider.ts      # Interface
│   │       ├── MockVisionProvider.ts
│   │       └── (future: OpenAIVisionProvider.ts)
│   ├── services/
│   │   ├── FashionQueryGenerator.ts
│   │   └── MarketplaceAggregator.ts
│   ├── connectors/
│   │   ├── MarketplaceConnector.ts    # Protocole
│   │   └── MockConnector.ts
│   └── types/
└── package.json
```

### 1.4 Flux de données

- **App Group** : `group.flowerz.io.Balibu` — stockage SharedImagePayload (référence fichier + métadonnées)
- **UserDefaults(suiteName:)** : clé `sharedImagePayload` pour notifier l'app
- **Backend** : POST `/analyze-search` — multipart image → JSON response

### 1.5 Choix techniques

- **SwiftUI** : App principale uniquement. Share Extension = UIKit (contrainte Apple).
- **async/await** : Partout
- **URLSession** : Pas de lib externe
- **Pas de dépendances iOS** : Sauf si justifiée
- **Backend** : Fastify (plus simple que Next.js pour une API pure MVP)
