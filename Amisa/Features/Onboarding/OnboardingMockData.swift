//
//  OnboardingMockData.swift
//  Amisa
//

import SwiftUI

struct DemoListing: Identifiable, Equatable {
    let id: String
    let imageName: String
    let brand: String
    let title: String
    let price: String
    let size: String?
    let providerLogoName: String
}

struct DemoLook: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let imageName: String
    /// Libellé de la pièce simulée par l’IA (focus analyse → résultats).
    let detectedPiece: String
    /// Libellé court affiché à la confirmation (« Sac détecté », etc.).
    let detectionConfirmLabel: String
    /// Zone de focus normalisée (0…1) pour la détection sur la photo.
    let focusRect: CGRect
    let results: [DemoListing]
}

struct OnboardingHeroCardData {
    let imageName: String
    let brand: String
    let title: String
    let price: String
    let size: String?
    let providerLogoName: String
}

enum OnboardingMockData {

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

    private static let leatherItems: [(String, String, String, String?, String)] = [
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

    private static let sneakerheadItems: [(String, String, String, String?, String)] = [
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

    private static let urbanCoolItems: [(String, String, String, String?, String)] = [
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

    private static let smartCasualItems: [(String, String, String, String?, String)] = [
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

    static let demoLooks: [DemoLook] = [
        DemoLook(
            id: "feminine",
            title: "Look féminin",
            subtitle: "Style lifestyle",
            imageName: "onboarding_look_shirt",
            detectedPiece: "Chemise oxford",
            detectionConfirmLabel: "Sac détecté",
            focusRect: OnboardingAnalysisFocusPresets.female.normalizedRect,
            results: makeFeminineSneakerListings()
        ),
        DemoLook(
            id: "masculine",
            title: "Look masculin",
            subtitle: "Style lifestyle",
            imageName: "onboarding_look_leather",
            detectedPiece: "Veste en cuir",
            detectionConfirmLabel: "Jean détecté",
            focusRect: OnboardingAnalysisFocusPresets.male.normalizedRect,
            results: makeMasculineCapListings()
        ),
    ]

    private static let onitsukaSneakerTitles = [
        "Mexico 66 jaune",
        "Mexico",
        "Mexico 66",
        "66 jaune",
        "Mexico jaune",
    ]

    /// Tailles fixes pseudo-aléatoires (37…45), ordre naturel non croissant.
    private static let feminineSneakerSizes = [
        "42", "39", "44", "38", "41", "37", "43", "40", "45", "39", "42", "38",
    ]

    private static let masculineCapBrands = [
        "New Era", "New Era", "47 Brand", "New Era", "NY Yankees", "New Era", "Nike", "New Era", "47 Brand", "New Era",
        "New Era", "47 Brand", "New Era", "NY Yankees", "New Era", "Nike", "New Era", "47 Brand", "New Era", "New Era",
    ]

    private static let masculineCapTitles = [
        "NY Yankees", "New York Yankees", "Yankees", "New York", "NY", "NY Yankees", "New York", "Yankees",
        "NY Yankees", "New York Yankees", "NY", "New York", "Yankees", "NY Yankees", "New York Yankees", "New York",
        "NY", "Yankees", "NY Yankees", "New York",
    ]

    /// Prix casquettes (5€–30€), ordre fixe pseudo-aléatoire.
    private static let masculineCapPrices = [
        "12 €", "18 €", "9 €", "24 €", "15 €", "7 €", "29 €", "14 €", "22 €", "11 €",
        "19 €", "8 €", "26 €", "13 €", "21 €", "16 €", "6 €", "28 €", "10 €", "17 €",
    ]

    private static func makeMasculineCapListings() -> [DemoListing] {
        urbanCoolItems.enumerated().map { idx, item in
            let imageIndex = (idx % 6) + 1
            return DemoListing(
                id: "masculine_\(String(format: "%03d", idx + 1))",
                imageName: "onboarding_result_cap_\(String(format: "%02d", imageIndex))",
                brand: masculineCapBrands[idx % masculineCapBrands.count],
                title: masculineCapTitles[idx % masculineCapTitles.count],
                price: masculineCapPrices[idx % masculineCapPrices.count],
                size: "OS",
                providerLogoName: item.4
            )
        }
    }

    private static func makeFeminineSneakerListings() -> [DemoListing] {
        sneakerheadItems.enumerated().map { idx, item in
            let imageIndex = (idx % 6) + 1
            return DemoListing(
                id: "feminine_\(String(format: "%03d", idx + 1))",
                imageName: "onboarding_result_sneaker_\(String(format: "%02d", imageIndex))",
                brand: "Onitsuka Tiger",
                title: onitsukaSneakerTitles[idx % onitsukaSneakerTitles.count],
                price: item.2,
                size: feminineSneakerSizes[idx % feminineSneakerSizes.count],
                providerLogoName: item.4
            )
        }
    }

    private static func makeListings(
        lookId: String,
        prefix: String,
        items: [(String, String, String, String?, String)]
    ) -> [DemoListing] {
        items.enumerated().map { idx, item in
            let imageIndex = (idx % 6) + 1
            return DemoListing(
                id: "\(lookId)_\(String(format: "%03d", idx + 1))",
                imageName: "\(prefix)_\(String(format: "%02d", imageIndex))",
                brand: item.0,
                title: item.1,
                price: item.2,
                size: item.3,
                providerLogoName: item.4
            )
        }
    }
}

struct OnboardingAssetImageView: View {
    let imageName: String
    var contentMode: ContentMode = .fill
    /// Zone de focus normalisée (0…1) pour un crop centré sur le sujet ; `nil` = centré.
    var focusRect: CGRect? = nil

    @State private var isVisible = false

    private var hasAsset: Bool { UIImage(named: imageName) != nil }

    var body: some View {
        ZStack {
            if hasAsset {
                OnboardingImageSkeleton()
            } else {
                OnboardingImageFallback()
            }

            if hasAsset {
                Group {
                    if let focusRect {
                        OnboardingSubjectFillImage(imageName: imageName, focusRect: focusRect)
                    } else {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                    }
                }
                .opacity(isVisible ? 1 : 0)
            }
        }
        .onAppear {
            guard hasAsset else { return }
            withAnimation(.easeOut(duration: 0.32)) {
                isVisible = true
            }
        }
        .onChange(of: imageName) { _, _ in
            isVisible = false
            guard hasAsset else { return }
            withAnimation(.easeOut(duration: 0.32)) {
                isVisible = true
            }
        }
    }

}

// MARK: - Crop centré sujet (onboarding looks)

private struct OnboardingSubjectFillImage: View {
    let imageName: String
    let focusRect: CGRect

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            if let uiImage = UIImage(named: imageName) {
                let offset = FocusImageCrop.offset(
                    container: size,
                    imageSize: uiImage.size,
                    focusRect: focusRect
                )
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .offset(offset)
                    .frame(width: size.width, height: size.height)
                    .clipped()
            }
        }
    }

}
