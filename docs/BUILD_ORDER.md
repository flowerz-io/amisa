# Ordre de développement — Balibu MVP

Ordre recommandé du plus critique au moins critique.

## Phase 1 — Fondations (sans backend)

1. **Projet Xcode** — targets, App Groups, entitlements, URL scheme
2. **Modèles** — SharedImagePayload, FashionVisionResult, StructuredFashionQuery, MarketplaceListing, SearchSession, SearchState
3. **ShareStorageService** — UserDefaults App Group, savePayload / consumePayload / clearPayload
4. **ImagePersistenceService** — saveImage, fullPath, persistThumbnail, cleanupTemporaryImage, deleteImage
5. **Share Extension** — ShareItemExtractor, ShareExtensionStorage, ShareViewController (sans ouvrir l'app)
6. **App principale** — BalibuApp, Router, AppRouter avec navigation basique
7. **HomeView** — layout, share flow, import Photos (via saveImage + SharedImagePayload)
8. **SharedImportReviewView** — affichage image, bouton search, loading (mock)
9. **SearchHistoryService** — addSession, recentSessions, sessions
10. **SearchHistoryView** — liste historique
11. **ResultsView** — affichage mock
12. **APIClient** — analyseAndSearch, gestion erreurs
13. **SharedImportReviewViewModel** — appel API réel, création SearchSession

## Phase 2 — Backend

14. **Backend** — Fastify, route POST /analyze-search
15. **VisionProvider mock** — extraction attributs, génération requête
16. **Marketplace mock** — listings mock réalistes
17. **Tester** — end-to-end Share → Review → Results

## Phase 3 — UX & polish

18. **Design tokens** — cohérence UI
19. **États erreur** — image non exploitable, aucun résultat, backend indisponible
20. **Ouverture app** — depuis Share Extension (si possible)
