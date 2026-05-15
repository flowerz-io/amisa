# Provider logos (PNG)

Emplacement source recommandé dans le repo :

- `Balibu/Resources/ProviderLogos/`

Noms exacts de fichiers PNG à conserver :

- `provider_vinted.png`
- `provider_grailed.png`
- `provider_leboncoin.png`
- `provider_ebay.png`
- `provider_depop.png`
- `provider_facebookmarketplace.png`

Intégration iOS runtime :

1. Ajouter chaque logo dans `Balibu/Assets.xcassets` avec exactement le même nom d’asset (sans `.png`).
2. Vérifier que chaque asset expose les variantes 1x/2x/3x si nécessaire.
3. Le code lit ces assets via `MarketplaceSource.logoAssetName(from:)`.

Fallback :

- Si un logo n’existe pas encore dans les assets, l’app affiche automatiquement un badge texte discret (sans crash).
