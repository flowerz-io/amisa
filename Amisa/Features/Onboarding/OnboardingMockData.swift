//
//  OnboardingMockData.swift
//  Balibu
//
//  SOURCE UNIQUE de toute la data fake de l'onboarding.
//  Aucune image n'est hardcodée dans les vues — tout passe par ces structs.
//
//  ┌──────────────────────────────────────────────────────────────────────┐
//  │  ASSETS À CRÉER / REMPLACER DANS XCODE                              │
//  │  Chemin : Assets.xcassets > Onboarding >                            │
//  ├──────────────────────────────────────────────────────────────────────┤
//  │  HERO CARDS (HeroCards/)                                             │
//  │    onboarding_hero_card_01   ← carte principale (foreground)         │
//  │    onboarding_hero_card_02   ← carte droite (blurred back)           │
//  │    onboarding_hero_card_03   ← carte gauche (blurred back)           │
//  ├──────────────────────────────────────────────────────────────────────┤
//  │  LOOK OPTIONS (Looks/)                                               │
//  │    onboarding_look_leather   ← look cuir                             │
//  │    onboarding_look_sneaker   ← look sneakers                         │
//  │    onboarding_look_cap       ← look casquette / streetwear           │
//  │    onboarding_look_shirt     ← look smart casual / chemise           │
//  ├──────────────────────────────────────────────────────────────────────┤
//  │  FAKE RESULTS (Results/) — 6 visuels par look (cycle sur 20 cartes) │
//  │                                                                      │
//  │  Cuir    : onboarding_result_leather_01 … onboarding_result_leather_06 │
//  │  Sneaker : onboarding_result_sneaker_01 … onboarding_result_sneaker_06 │
//  │  Cap     : onboarding_result_cap_01    … onboarding_result_cap_06    │
//  │  Chemise : onboarding_result_shirt_01  … onboarding_result_shirt_06  │
//  │                                                                      │
//  │  💡 Astuce : 6 vraies photos suffisent — elles sont réutilisées     │
//  │     sur les 20 cartes résultats. Ajouter plus pour plus de variété.  │
//  ├──────────────────────────────────────────────────────────────────────┤
//  │  PROVIDER LOGOS (Assets.xcassets root, déjà présents)               │
//  │    provider_vinted                                                   │
//  │    provider_vinted                                                  │
//  │    provider_vinted                                                     │
//  │    provider_vinted                                                    │
//  └──────────────────────────────────────────────────────────────────────┘

import SwiftUI

// MARK: - Models

/// Une carte produit sur l'écran hero.
struct OnboardingHeroCardData {
    let imageName: String       // Asset name — ex: "onboarding_hero_card_01"
    let brand: String
    let title: String
    let price: String
    let size: String?
    let providerLogoName: String // Asset name — ex: "provider_vinted"
}

/// Un look sélectionnable sur la page démo.
struct OnboardingLookOptionData: Identifiable {
    let id: String              // Clé stable — ex: leather, sneakerhead, urbanCool, smartCasual
    let title: String
    let subtitle: String        // Sous-titre de la carte look
    let imageName: String       // Asset name — ex: "onboarding_look_leather"
    let scanLabel: String       // Label affiché dans la pastille de scan (indépendant du subtitle)
}

/// Un résultat fake dans la grille de résultats démo.
struct OnboardingFakeResultData: Identifiable {
    let id: String              // Unique — ex: "leather_001"
    let lookId: String          // ID du look parent — ex: "leather"
    let imageName: String       // Asset name — ex: "onboarding_result_leather_01"
    let brand: String
    let title: String
    let price: String
    let size: String?
    let providerLogoName: String
}

// MARK: - Data source

enum OnboardingMockData {

    // MARK: Hero cards (3 cartes flottantes)

    static let heroCards: [OnboardingHeroCardData] = [
        OnboardingHeroCardData(
            imageName:       "onboarding_hero_card_01",
            brand:           "Schott NYC",
            title:           "Veste biker cuir",
            price:           "89 €",
            size:            "M",
            providerLogoName: "provider_vinted"
        ),
        OnboardingHeroCardData(
            imageName:       "onboarding_hero_card_02",
            brand:           "Nike",
            title:           "Air Force 1 '07",
            price:           "120 €",
            size:            "42",
            providerLogoName: "provider_vinted"
        ),
        OnboardingHeroCardData(
            imageName:       "onboarding_hero_card_03",
            brand:           "Burberry",
            title:           "Trench coat classique",
            price:           "185 €",
            size:            "S",
            providerLogoName: "provider_vinted"
        ),
    ]

    // MARK: Look options (4 styles à sélectionner)

    static let lookOptions: [OnboardingLookOptionData] = [
        OnboardingLookOptionData(id: "leather", title: "Look Cuir", subtitle: "Veste en cuir", imageName: "onboarding_look_leather", scanLabel: "option 1"),
        OnboardingLookOptionData(id: "sneakerhead", title: "Sneakerhead", subtitle: "Sneakers", imageName: "onboarding_look_sneaker", scanLabel: "option 2"),
        OnboardingLookOptionData(id: "urbanCool", title: "Urban Cool", subtitle: "Casquette", imageName: "onboarding_look_cap", scanLabel: "option 3"),
        OnboardingLookOptionData(id: "smartCasual", title: "Smart Casual", subtitle: "Chemise oxford", imageName: "onboarding_look_shirt", scanLabel: "option 4"),
    ]

    // MARK: Fake results — filtrage par lookId

    /// Retourne 20 résultats fake pour le look donné.
    static func fakeResults(for lookId: String) -> [OnboardingFakeResultData] {
        allFakeResults.filter { $0.lookId == lookId }
    }

    // MARK: Pool complet (20 entrées × 4 looks = 80 résultats)
    // Les imageName cyclent sur 6 stubs : onboarding_result_{look}_01 … _06

    private static let allFakeResults: [OnboardingFakeResultData] = leatherResults
        + sneakerheadResults
        + urbanCoolResults
        + smartCasualResults

    // MARK: Leather results

    private static let leatherResults: [OnboardingFakeResultData] = makeResults(
        lookId: "leather",
        prefix: "onboarding_result_leather",
        items: [
            ("Schott NYC",    "Veste biker cuir",      "149 €", "M",   "provider_vinted"),
            ("Lewis Leathers","Perfecto cuir vintage",  "285 €", "L",   "provider_vinted"),
            ("Acne Studios",  "Veste cuir oversize",    "320 €", "S",   "provider_vinted"),
            ("AllSaints",     "Biker jacket noir",       "89 €", "M",   "provider_vinted"),
            ("Our Legacy",    "Leather jacket slim",    "210 €", "L",   "provider_vinted"),
            ("Sandro",        "Veste cuir camel",       "145 €", "S",   "provider_vinted"),
            ("ZARA",          "Biker cuir perfecto",     "45 €", nil,   "provider_vinted"),
            ("Weekday",       "Veste cuir brodée",       "65 €", "M",   "provider_vinted"),
            ("& Other Stories","Perfecto court",         "99 €", "36",  "provider_vinted"),
            ("Maje",          "Veste cuir cognac",      "175 €", "M",   "provider_vinted"),
            ("Closed",        "Leather blouson",        "240 €", "M",   "provider_vinted"),
            ("Arket",         "Biker beige",            "180 €", "S",   "provider_vinted"),
            ("Ikks",          "Veste cuir souple",       "79 €", nil,   "provider_vinted"),
            ("IRO Paris",     "Blouson cuir zippé",     "265 €", "36",  "provider_vinted"),
            ("Muubaa",        "Moto jacket",            "135 €", "M",   "provider_vinted"),
            ("Deadwood",      "Paloma jacket",          "190 €", "S",   "provider_vinted"),
            ("Belstaff",      "Blouson Trialmaster",    "480 €", "L",   "provider_vinted"),
            ("Serge Pariente","Teddy cuir vintage",      "95 €", "M",   "provider_vinted"),
            ("Topshop",       "Faux leather jacket",     "35 €", "10",  "provider_vinted"),
            ("Levi's",        "Trucker cuir synthétique","55 €", "M",   "provider_vinted"),
        ]
    )

    // MARK: Sneaker results

    private static let sneakerheadResults: [OnboardingFakeResultData] = makeResults(
        lookId: "sneakerhead",
        prefix: "onboarding_result_sneaker",
        items: [
            ("Nike",        "Air Force 1 '07",         "89 €", "42",  "provider_vinted"),
            ("Converse",    "Chuck Taylor All Star",    "55 €", "41",  "provider_vinted"),
            ("Nike",        "Dunk Low Retro",          "130 €", "43",  "provider_vinted"),
            ("Vans",        "Old Skool",                "65 €", "42",  "provider_vinted"),
            ("Adidas",      "Gazelle",                  "79 €", "40",  "provider_vinted"),
            ("Adidas",      "Stan Smith",               "69 €", "43",  "provider_vinted"),
            ("New Balance",  "574 Classic",             "95 €", "42",  "provider_vinted"),
            ("Nike",        "Air Max 90",              "110 €", "44",  "provider_vinted"),
            ("Jordan",      "Air Jordan 1 Retro",      "185 €", "42",  "provider_vinted"),
            ("Adidas",      "Samba OG",                 "99 €", "41",  "provider_vinted"),
            ("Asics",       "Gel-Lyte III",             "85 €", "42",  "provider_vinted"),
            ("New Balance",  "990v5",                  "155 €", "43",  "provider_vinted"),
            ("Nike",        "Blazer Mid '77",           "75 €", "41",  "provider_vinted"),
            ("Puma",        "Suede Classic",            "55 €", "42",  "provider_vinted"),
            ("Reebok",      "Classic Leather",          "65 €", "43",  "provider_vinted"),
            ("Salomon",     "XT-6",                    "160 €", "42",  "provider_vinted"),
            ("Vans",        "Sk8-Hi",                   "70 €", "41",  "provider_vinted"),
            ("Nike",        "Air Max 95",              "140 €", "44",  "provider_vinted"),
            ("Adidas",      "Forum Low",                "80 €", "42",  "provider_vinted"),
            ("New Balance",  "530 Silver",              "89 €", "40",  "provider_vinted"),
        ]
    )

    // MARK: Cap results

    private static let urbanCoolResults: [OnboardingFakeResultData] = makeResults(
        lookId: "urbanCool",
        prefix: "onboarding_result_cap",
        items: [
            ("Supreme",         "Casquette 6-panel",      "65 €", nil, "provider_vinted"),
            ("Carhartt WIP",    "Dad hat kaki",            "45 €", nil, "provider_vinted"),
            ("New Era",         "59Fifty Fitted",          "35 €", nil, "provider_vinted"),
            ("Palace",          "Snapback tri-ferg",       "75 €", nil, "provider_vinted"),
            ("Stüssy",          "Stock Low Pro",           "55 €", nil, "provider_vinted"),
            ("Kith",            "Cap brodé logo",          "55 €", nil, "provider_vinted"),
            ("Patagonia",       "P-6 Logo Hat",            "45 €", nil, "provider_vinted"),
            ("Aimé Leon Dore",  "Ball Cap blanc",          "80 €", nil, "provider_vinted"),
            ("Gramicci",        "Shell camp cap",          "48 €", nil, "provider_vinted"),
            ("Acne Studios",    "Carlino cap",             "95 €", nil, "provider_vinted"),
            ("Noah",            "Winged foot cap",         "68 €", nil, "provider_vinted"),
            ("Patta",           "Basic Wool Cap",          "55 €", nil, "provider_vinted"),
            ("HUF",             "Essentials cap",          "38 €", nil, "provider_vinted"),
            ("Pop Trading Co.", "Volley cap",              "62 €", nil, "provider_vinted"),
            ("Aloha Sunday",    "Sunday 5-panel",          "52 €", nil, "provider_vinted"),
            ("Stone Island",    "Cap brodée logo",        "120 €", nil, "provider_vinted"),
            ("Lacoste",         "Classic Twill cap",       "42 €", nil, "provider_vinted"),
            ("Le 31",           "Cap sergé",               "28 €", nil, "provider_vinted"),
            ("Adidas",          "Trefoil cap",             "35 €", nil, "provider_vinted"),
            ("Nike",            "Club Cap unstructured",   "30 €", nil, "provider_vinted"),
        ]
    )

    // MARK: Shirt results

    private static let smartCasualResults: [OnboardingFakeResultData] = makeResults(
        lookId: "smartCasual",
        prefix: "onboarding_result_shirt",
        items: [
            ("UNIQLO",         "Oxford shirt blanc",      "29 €", "M",  "provider_vinted"),
            ("Sandro",         "Chemise lin écru",        "95 €", "L",  "provider_vinted"),
            ("Ralph Lauren",   "OCBD button-down",        "85 €", "M",  "provider_vinted"),
            ("Patagonia",      "Chemise flanelle",        "79 €", "L",  "provider_vinted"),
            ("COS",            "Chemise popeline",        "69 €", "M",  "provider_vinted"),
            ("Jacquemus",      "Linen shirt bleu",       "215 €", "S",  "provider_vinted"),
            ("Acne Studios",   "Chemise oversize",       "180 €", "M",  "provider_vinted"),
            ("Our Legacy",     "Band collar shirt",      "165 €", "M",  "provider_vinted"),
            ("AMI Paris",      "Chemise lin blanc",      "175 €", "M",  "provider_vinted"),
            ("Carhartt WIP",   "Work shirt",              "89 €", "L",  "provider_vinted"),
            ("Officine Générale","Chemise twill",        "145 €", "M",  "provider_vinted"),
            ("Arket",          "Relaxed oxford shirt",    "75 €", "L",  "provider_vinted"),
            ("Barbour",        "Chemise tartan",          "95 €", "M",  "provider_vinted"),
            ("A.P.C.",         "Chemise Teo",            "140 €", "S",  "provider_vinted"),
            ("Vilebrequin",    "Chemise lin rayée",      "120 €", "L",  "provider_vinted"),
            ("Maison Labiche", "Chemise brodée",         "115 €", "M",  "provider_vinted"),
            ("Isabel Marant",  "Chemise chemisier",      "195 €", "36", "provider_vinted"),
            ("Études",         "Chemise logotypée",       "99 €", "M",  "provider_vinted"),
            ("Filippa K",      "Chemise popeline GOTS",  "130 €", "M",  "provider_vinted"),
            ("Selected Homme", "Chemise slim",            "45 €", "L",  "provider_vinted"),
        ]
    )

    // MARK: Factory

    private static func makeResults(
        lookId: String,
        prefix: String,
        items: [(String, String, String, String?, String)]
    ) -> [OnboardingFakeResultData] {
        items.enumerated().map { idx, item in
            // Cycle les 6 visuels disponibles (01…06)
            let imageIndex = (idx % 6) + 1
            let imageIndexStr = String(format: "%02d", imageIndex)
            return OnboardingFakeResultData(
                id:              "\(lookId)_\(String(format: "%03d", idx + 1))",
                lookId:          lookId,
                imageName:       "\(prefix)_\(imageIndexStr)",
                brand:           item.0,
                title:           item.1,
                price:           item.2,
                size:            item.3,
                providerLogoName: item.4
            )
        }
    }
}
