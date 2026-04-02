# Balibu — Configuration Xcode MVP

## Nom du projet
**Balibu**

## Targets

| Target | Type | Description |
|--------|------|-------------|
| Balibu | Application | App principale iOS |
| BalibuShareExtension | App Extension | Share Extension pour recevoir les images |
| BalibuTests | Unit Tests | Tests unitaires |
| BalibuUITests | UI Tests | Tests UI |

## Bundle Identifiers

| Target | Bundle ID |
|--------|-----------|
| Balibu | `flowerz.io.Balibu.app` |
| BalibuShareExtension | `flowerz.io.Balibu.app.ShareExtension` |
| BalibuTests | `flowerz.io.BalibuTests` |
| BalibuUITests | `flowerz.io.BalibuUITests` |

## Capabilities requises

### Balibu (app principale)
- **App Groups** : `group.flowerz.io.Balibu`
- **Network** (par défaut, pour URLSession)

### BalibuShareExtension
- **App Groups** : `group.flowerz.io.Balibu`

## App Groups

**Identifiant** : `group.flowerz.io.Balibu`

Ce groupe doit être activé sur les deux targets (Balibu et BalibuShareExtension) pour partager :
- le chemin de l’image partagée (`shared_image_url`)
- le flag de payload disponible (`shared_payload_available`)

## Deployment Target

- **iOS 17.0** (ou 17.6 si déjà défini dans le projet)

## Schemes

- **Balibu** : build et lance l’app principale
- **BalibuShareExtension** : build uniquement l’extension (testée via l’app principale)

## Fichiers Plist importants

### Balibu/Info.plist
- `CFBundleURLTypes` : URL scheme `balibu://` pour ouvrir l’app depuis l’extension
- `LSApplicationQueriesSchemes` : si besoin d’ouvrir des liens externes
- `NSPhotoLibraryUsageDescription` : pour l’import depuis Photos
- `NSCameraUsageDescription` : si caméra utilisée plus tard

### BalibuShareExtension/Info.plist
- `NSExtension` : configuration Share Extension
- `NSExtensionActivationRule` : restreindre aux images (et optionnellement vidéo)
- `NSExtensionPrincipalClass` : si on passe en code-only (sans storyboard)

### Activation Rule (images prioritaires)
```xml
<key>NSExtensionActivationRule</key>
<dict>
    <key>NSExtensionActivationSupportsImageWithMaxCount</key>
    <integer>1</integer>
    <key>NSExtensionActivationSupportsMovieWithMaxCount</key>
    <integer>0</integer>
</dict>
```
Ou plus souple : `NSExtensionActivationSupportsImageWithMaxCount = 1` + support vidéo = 0 pour MVP.

## Fichiers à créer

### App & Core
- `Balibu/App/BalibuApp.swift`
- `Balibu/App/AppRouter.swift`
- `Balibu/Core/DesignSystem/DesignTokens.swift`
- `Balibu/Core/DesignSystem/BalibuButtonStyle.swift`
- `Balibu/Core/Utils/`

### Models
- `Balibu/Models/SharedImagePayload.swift`
- `Balibu/Models/FashionVisionResult.swift`
- `Balibu/Models/StructuredFashionQuery.swift`
- `Balibu/Models/MarketplaceListing.swift`
- `Balibu/Models/SearchSession.swift`
- `Balibu/Models/SearchState.swift`

### Services
- `Balibu/Services/APIClient.swift`
- `Balibu/Services/ShareStorageService.swift`
- `Balibu/Services/ImagePersistenceService.swift`
- `Balibu/Services/SearchHistoryService.swift`

### Features
- `Balibu/Features/Home/HomeView.swift`
- `Balibu/Features/Home/HomeViewModel.swift`
- `Balibu/Features/SharedImport/SharedImportReviewView.swift`
- `Balibu/Features/SharedImport/SharedImportReviewViewModel.swift`
- `Balibu/Features/Results/ResultsView.swift`
- `Balibu/Features/Results/ResultsViewModel.swift`
- `Balibu/Features/SearchHistory/SearchHistoryView.swift`
- `Balibu/Features/SearchHistory/SearchHistoryViewModel.swift`

### Extensions
- `Balibu/Extensions/URL+Helpers.swift`
- `Balibu/Extensions/Image+Helpers.swift`

### Share Extension
- `BalibuShareExtension/ShareViewController.swift` (réécrire)
- `BalibuShareExtension/ShareItemExtractor.swift`
- `BalibuShareExtension/ShareExtensionConstants.swift`

## Entitlements

Créer si nécessaire :
- `Balibu/Balibu.entitlements` : App Groups
- `BalibuShareExtension/BalibuShareExtension.entitlements` : App Groups
