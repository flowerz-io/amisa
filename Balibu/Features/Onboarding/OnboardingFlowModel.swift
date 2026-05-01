//
//  OnboardingFlowModel.swift
//  Balibu
//

import SwiftUI
import Combine

// MARK: - File-private source colors

private extension Color {
    static let srcVinted  = Color(red: 0.13, green: 0.73, blue: 0.50)
    static let srcGrailed = Color(red: 0.97, green: 0.33, blue: 0.18)
    static let srcEbay    = Color(red: 0.23, green: 0.49, blue: 0.96)
    static let srcDepop   = Color(red: 0.96, green: 0.22, blue: 0.38)
}

// MARK: - Enums

enum OnboardingStep: Int, CaseIterable {
    case hero
    case gender
    case country
    case demo
    case paywall
}

enum OnboardingGender: String {
    case female, male

    var displayName: String { self == .female ? "Femme" : "Homme" }

    var icon: String { self == .female ? "figure.stand.dress" : "figure.stand" }

    var gradientColors: [Color] {
        self == .female
            ? [Color(red: 0.95, green: 0.72, blue: 0.80), Color(red: 0.88, green: 0.50, blue: 0.65)]
            : [Color(red: 0.20, green: 0.35, blue: 0.60), Color(red: 0.10, green: 0.22, blue: 0.45)]
    }
}

enum OnboardingCountry: String, CaseIterable, Identifiable {
    case france, belgique, suisse, uk, italie, espagne, portugal, netherlands, europe, us, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .france:      "France"
        case .belgique:    "Belgique"
        case .suisse:      "Suisse"
        case .uk:          "Royaume-Uni"
        case .italie:      "Italie"
        case .espagne:     "Espagne"
        case .portugal:    "Portugal"
        case .netherlands: "Pays-Bas"
        case .europe:      "Europe"
        case .us:          "États-Unis"
        case .other:       "Autre"
        }
    }

    var flag: String {
        switch self {
        case .france:      "🇫🇷"
        case .belgique:    "🇧🇪"
        case .suisse:      "🇨🇭"
        case .uk:          "🇬🇧"
        case .italie:      "🇮🇹"
        case .espagne:     "🇪🇸"
        case .portugal:    "🇵🇹"
        case .netherlands: "🇳🇱"
        case .europe:      "🇪🇺"
        case .us:          "🇺🇸"
        case .other:       "🌍"
        }
    }
}

// MARK: - Hero mock listings (4 cards — Supreme supprimée)

struct OnboardingMockListing: Identifiable {
    let id = UUID()
    let title: String
    let brand: String
    let price: String
    let size: String?
    let source: String
    let sourceColor: Color
    let imageName: String
    let gradientColors: [Color]
}

extension OnboardingMockListing {
    static let samples: [OnboardingMockListing] = [
        OnboardingMockListing(
            title: "Veste biker cuir",
            brand: "Schott NYC",
            price: "89 €",
            size: "M",
            source: "Vinted",
            sourceColor: .srcVinted,
            imageName: "hero_leather_jacket",
            gradientColors: [Color(red: 0.18, green: 0.15, blue: 0.12), Color(red: 0.35, green: 0.28, blue: 0.22)]
        ),
        OnboardingMockListing(
            title: "Air Force 1 '07",
            brand: "Nike",
            price: "120 €",
            size: "42",
            source: "Grailed",
            sourceColor: .srcGrailed,
            imageName: "hero_air_force",
            gradientColors: [Color(red: 0.88, green: 0.86, blue: 0.82), Color(red: 0.76, green: 0.74, blue: 0.70)]
        ),
        OnboardingMockListing(
            title: "Trench coat classique",
            brand: "Burberry",
            price: "185 €",
            size: "S",
            source: "eBay",
            sourceColor: .srcEbay,
            imageName: "hero_trench",
            gradientColors: [Color(red: 0.82, green: 0.74, blue: 0.60), Color(red: 0.68, green: 0.58, blue: 0.44)]
        ),
        OnboardingMockListing(
            title: "Manteau laine camel",
            brand: "Sandro",
            price: "95 €",
            size: "38",
            source: "Depop",
            sourceColor: .srcDepop,
            imageName: "hero_camel_coat",
            gradientColors: [Color(red: 0.80, green: 0.68, blue: 0.52), Color(red: 0.65, green: 0.54, blue: 0.38)]
        ),
    ]
}

// MARK: - Look categories

enum OnboardingLookCategory: String {
    case coat, sneaker, dress, leather, cap, shirt

    var results: [OnboardingMockResult] {
        switch self {
        case .coat:    return OnboardingMockResult.coatResults
        case .sneaker: return OnboardingMockResult.sneakerResults
        case .dress:   return OnboardingMockResult.dressResults
        case .leather: return OnboardingMockResult.leatherResults
        case .cap:     return OnboardingMockResult.capResults
        case .shirt:   return OnboardingMockResult.shirtResults
        }
    }
}

// MARK: - Mock result

struct OnboardingMockResult: Identifiable {
    let id: Int
    let title: String
    let brand: String
    let price: String
    let size: String?
    let source: String
    let sourceColor: Color
    let imageName: String
}

// MARK: - 20 results per category

extension OnboardingMockResult {

    static let leatherResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Veste biker cuir",       "Schott NYC",     "149 €", "M",   v, 1),
            ("Perfecto cuir vintage",  "Lewis Leathers", "285 €", "L",   g, 2),
            ("Veste cuir oversize",    "Acne Studios",   "320 €", "S",   e, 3),
            ("Biker jacket",           "AllSaints",       "89 €", "M",   d, 4),
            ("Leather jacket slim",    "Our Legacy",     "210 €", "L",   g, 5),
            ("Veste cuir camel",       "Sandro",         "145 €", "S",   v, 6),
            ("Biker cuir noir",        "ZARA",            "45 €", "38",  d, 1),
            ("Veste cuir brodée",      "Weekday",         "65 €", "M",   e, 2),
            ("Perfecto court",         "&Other Stories",  "99 €", "36",  v, 3),
            ("Biker cuir usé",         "H&M",             "39 €", "L",   g, 4),
            ("Veste cuir cognac",      "Maje",           "175 €", "M",   d, 5),
            ("Leather biker vintage",  "Levi's",          "79 €", "M",   e, 6),
            ("Veste cuir western",     "Free People",    "130 €", "S",   v, 1),
            ("Moto jacket cuir",       "IRO Paris",      "290 €", "36",  g, 2),
            ("Cuir noir zippé",        "Topshop",         "55 €", "M",   d, 3),
            ("Perfecto agneau",        "Ba&sh",          "195 €", "S",   e, 4),
            ("Veste cuir vintage 80s", "Vintage",        "120 €", "M",   v, 5),
            ("Biker jacket beige",     "MANGO",           "69 €", "M",   g, 6),
            ("Cuir oversize cropped",  "Arket",          "185 €", "S",   d, 1),
            ("Veste moto cuir",        "COS",            "149 €", "36",  e, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_leather_\(s.5)")
        }
    }()

    static let sneakerResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Air Force 1 '07",   "Nike",          "89 €",  "42", g, 1),
            ("Chuck Taylor",      "Converse",       "55 €",  "41", v, 2),
            ("Dunk Low Retro",    "Nike",          "130 €",  "43", g, 3),
            ("Old Skool",         "Vans",           "65 €",  "42", d, 4),
            ("Gazelle",           "Adidas",         "79 €",  "40", v, 5),
            ("Stan Smith",        "Adidas",         "69 €",  "43", d, 6),
            ("New Balance 574",   "New Balance",    "95 €",  "42", g, 1),
            ("Air Max 90",        "Nike",          "110 €",  "44", e, 2),
            ("Jordan 1 Retro",    "Jordan",        "185 €",  "42", g, 3),
            ("Samba OG",          "Adidas",         "99 €",  "41", v, 4),
            ("Sk8-Hi",            "Vans",           "75 €",  "43", d, 5),
            ("990v5",             "New Balance",   "149 €",  "42", e, 6),
            ("P-6000",            "Nike",           "89 €",  "40", g, 1),
            ("Forum Low",         "Adidas",         "85 €",  "43", v, 2),
            ("Air Max Plus TN",   "Nike",          "160 €",  "42", d, 3),
            ("Lyte III OG",       "ASICS",          "95 €",  "41", e, 4),
            ("Wave Rider 27",     "Mizuno",        "120 €",  "44", g, 5),
            ("Cloudmonster",      "On Running",    "159 €",  "42", v, 6),
            ("Ultra Boost 23",    "Adidas",        "135 €",  "43", d, 1),
            ("Gel-Lyte III",      "ASICS",         "110 €",  "42", e, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_sneaker_\(s.5)")
        }
    }()

    static let dressResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Robe midi lin",         "Sézane",          "120 €", "36",  v, 1),
            ("Robe slip dress",       "& Other Stories",  "89 €", "S",   d, 2),
            ("Robe longue fleurie",   "Ba&sh",           "145 €", "38",  e, 3),
            ("Robe wrap midi",        "DVF",             "280 €", "M",   g, 4),
            ("Robe midi stretch",     "MANGO",            "45 €", "S",   v, 5),
            ("Robe col carré",        "ZARA",             "35 €", "M",   d, 6),
            ("Robe plissée satin",    "H&M",              "29 €", "S",   v, 1),
            ("Robe fluide été",       "Reformation",     "185 €", "XS",  e, 2),
            ("Robe midi lilas",       "Arket",            "99 €", "36",  g, 3),
            ("Robe crochet",          "Zimmermann",      "340 €", "S",   d, 4),
            ("Robe smockée",          "Free People",     "110 €", "M",   v, 5),
            ("Robe linen blend",      "COS",              "89 €", "S",   e, 6),
            ("Robe midi vintage",     "Vintage",          "45 €", "38",  d, 1),
            ("Robe slip en soie",     "Equipment",       "195 €", "XS",  g, 2),
            ("Robe wrap fleurie",     "Marimekko",       "149 €", "S",   v, 3),
            ("Robe midi rayures",     "Sandro",          "165 €", "36",  d, 4),
            ("Robe longue bohème",    "Isabel Marant",   "280 €", "S",   e, 5),
            ("Robe midi coton",       "Uniqlo",           "39 €", "M",   v, 6),
            ("Robe babydoll",         "Ganni",           "195 €", "S",   g, 1),
            ("Robe chemise lin",      "APC",             "210 €", "36",  d, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_dress_\(s.5)")
        }
    }()

    static let coatResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Manteau camel",          "Sandro",          "195 €", "S",   v, 1),
            ("Manteau laine crème",    "COS",             "230 €", "36",  e, 2),
            ("Manteau oversized",      "Totême",          "580 €", "XS",  g, 3),
            ("Trench classique",       "Burberry",        "890 €", "S",   e, 4),
            ("Manteau check",          "Maje",            "175 €", "M",   v, 5),
            ("Manteau bouclé",         "ZARA",             "79 €", "S",   d, 6),
            ("Trench court",           "Claudie Pierlot", "245 €", "36",  v, 1),
            ("Manteau tweed",          "& Other Stories", "195 €", "S",   e, 2),
            ("Manteau laine navy",     "Arket",           "299 €", "M",   g, 3),
            ("Peacoat laine",          "A.P.C.",          "480 €", "S",   d, 4),
            ("Manteau carreaux",       "MANGO",            "89 €", "36",  v, 5),
            ("Long coat beige",        "Weekday",          "99 €", "S",   e, 6),
            ("Manteau drap laine",     "Sessùn",          "265 €", "M",   g, 1),
            ("Teddy coat crème",       "Free People",     "155 €", "S",   d, 2),
            ("Manteau suédé",          "Ba&sh",           "345 €", "36",  v, 3),
            ("Trench oversized",       "Isabel Marant",   "525 €", "S",   e, 4),
            ("Manteau vintage",        "Vintage",          "55 €", "M",   d, 5),
            ("Manteau léger",          "H&M",              "39 €", "M",   v, 6),
            ("Manteau déstructuré",    "Lemaire",         "680 €", "S",   g, 1),
            ("Duffle-coat marine",     "Gloverall",       "320 €", "36",  e, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_coat_\(s.5)")
        }
    }()

    static let capResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Casquette 6-panel",   "Supreme",         "65 €", nil, g, 1),
            ("Dad hat kaki",        "Carhartt WIP",    "45 €", nil, v, 2),
            ("New Era 59Fifty",     "New Era",         "35 €", nil, d, 3),
            ("Bucket hat",          "Columbia",        "39 €", nil, e, 4),
            ("Snapback logo",       "Palace",          "75 €", nil, g, 5),
            ("Casquette trucker",   "Obey",            "28 €", nil, v, 6),
            ("Logo cap",            "Nike",            "30 €", nil, d, 1),
            ("5-panel cap",         "Patagonia",       "45 €", nil, e, 2),
            ("Cap brodé",           "Kith",            "55 €", nil, g, 3),
            ("Bucket corduroy",     "Dickies",         "32 €", nil, v, 4),
            ("Stüssy cap",          "Stüssy",          "55 €", nil, d, 5),
            ("New Era Yankees",     "New Era",         "42 €", nil, e, 6),
            ("Logo cap vintage",    "Tommy Hilfiger",  "25 €", nil, g, 1),
            ("Casquette denim",     "Levi's",          "30 €", nil, v, 2),
            ("Camp cap",            "Gramicci",        "48 €", nil, d, 3),
            ("Cap suède",           "Reigning Champ",  "60 €", nil, e, 4),
            ("Fisherman beanie",    "Acne Studios",    "95 €", nil, g, 5),
            ("Logo cap blanc",      "Aimé Leon Dore",  "80 €", nil, v, 6),
            ("Cap brodé vintage",   "Vintage",         "18 €", nil, d, 1),
            ("Dad hat corduroy",    "Carhartt WIP",    "49 €", nil, e, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_cap_\(s.5)")
        }
    }()

    static let shirtResults: [OnboardingMockResult] = {
        typealias Src = (String, Color)
        let v: Src = ("Vinted",  .srcVinted)
        let g: Src = ("Grailed", .srcGrailed)
        let e: Src = ("eBay",    .srcEbay)
        let d: Src = ("Depop",   .srcDepop)
        let data: [(String, String, String, String?, Src, Int)] = [
            ("Oxford shirt blanc",  "UNIQLO",             "29 €", "M",  v, 1),
            ("Chemise lin écru",    "Sandro",             "95 €", "L",  d, 2),
            ("OCBD button-down",    "Ralph Lauren",       "85 €", "M",  g, 3),
            ("Chemise flanelle",    "Patagonia",          "79 €", "L",  e, 4),
            ("Chemise popeline",    "COS",                "69 €", "M",  v, 5),
            ("Linen shirt bleu",    "Jacquemus",         "215 €", "S",  d, 6),
            ("Chemise oversize",    "Acne Studios",      "180 €", "M",  g, 1),
            ("Chemise carreaux",    "Pendleton",          "99 €", "L",  e, 2),
            ("Oxford rose poudré",  "Reiss",              "89 €", "M",  v, 3),
            ("Chemise brodée",      "Drôle de Monsieur", "145 €", "L",  d, 4),
            ("Band collar shirt",   "Our Legacy",        "165 €", "M",  g, 5),
            ("Chemise western",     "Wrangler",           "55 €", "L",  e, 6),
            ("Chemise lin blanc",   "AMI Paris",         "175 €", "M",  v, 1),
            ("Chemise rayée",       "APC",               "130 €", "L",  d, 2),
            ("Chemise tencel",      "Arket",              "79 €", "M",  g, 3),
            ("Hawaï shirt",         "Stüssy",             "85 €", "L",  e, 4),
            ("Chemise denim",       "Edwin",              "65 €", "M",  v, 5),
            ("Work shirt",          "Carhartt WIP",       "89 €", "L",  d, 6),
            ("Chemise vintage",     "Vintage",            "22 €", "M",  g, 1),
            ("Chemise dobby",       "Corridor",          "145 €", "L",  e, 2),
        ]
        return data.enumerated().map { idx, s in
            .init(id: idx, title: s.0, brand: s.1, price: s.2, size: s.3,
                  source: s.4.0, sourceColor: s.4.1, imageName: "result_shirt_\(s.5)")
        }
    }()
}

// MARK: - Demo items

struct OnboardingDemoItem: Identifiable {
    let id: Int
    let label: String
    let focusPiece: String
    let imageName: String
    let category: OnboardingLookCategory
    let gradientColors: [Color]
}

extension OnboardingDemoItem {
    static let female: [OnboardingDemoItem] = [
        OnboardingDemoItem(id: 0, label: "Look Parisienne", focusPiece: "Manteau camel",  imageName: "look_female_parisienne", category: .coat,    gradientColors: [Color(red: 0.85, green: 0.72, blue: 0.58), Color(red: 0.70, green: 0.56, blue: 0.40)]),
        OnboardingDemoItem(id: 1, label: "Street Chic",     focusPiece: "Sneakers",        imageName: "look_female_street",     category: .sneaker, gradientColors: [Color(red: 0.14, green: 0.14, blue: 0.18), Color(red: 0.28, green: 0.26, blue: 0.34)]),
        OnboardingDemoItem(id: 2, label: "Summer Luxe",     focusPiece: "Robe midi",       imageName: "look_female_summer",     category: .dress,   gradientColors: [Color(red: 0.90, green: 0.82, blue: 0.72), Color(red: 0.78, green: 0.68, blue: 0.56)]),
        OnboardingDemoItem(id: 3, label: "Dark Academia",   focusPiece: "Veste en cuir",   imageName: "look_female_academia",   category: .leather, gradientColors: [Color(red: 0.18, green: 0.28, blue: 0.42), Color(red: 0.12, green: 0.20, blue: 0.35)]),
    ]

    static let male: [OnboardingDemoItem] = [
        OnboardingDemoItem(id: 0, label: "Leather Edge",  focusPiece: "Veste en cuir",  imageName: "look_male_leather", category: .leather, gradientColors: [Color(red: 0.14, green: 0.13, blue: 0.11), Color(red: 0.30, green: 0.25, blue: 0.20)]),
        OnboardingDemoItem(id: 1, label: "Sneakerhead",   focusPiece: "Nike Dunk Low",  imageName: "look_male_sneaker", category: .sneaker, gradientColors: [Color(red: 0.16, green: 0.22, blue: 0.58), Color(red: 0.28, green: 0.36, blue: 0.78)]),
        OnboardingDemoItem(id: 2, label: "Urban Cool",    focusPiece: "Casquette",      imageName: "look_male_urban",   category: .cap,     gradientColors: [Color(red: 0.78, green: 0.10, blue: 0.10), Color(red: 0.55, green: 0.08, blue: 0.08)]),
        OnboardingDemoItem(id: 3, label: "Smart Casual",  focusPiece: "Chemise oxford", imageName: "look_male_casual",  category: .shirt,   gradientColors: [Color(red: 0.32, green: 0.35, blue: 0.40), Color(red: 0.22, green: 0.25, blue: 0.30)]),
    ]
}

// MARK: - Asset image helper (shared across onboarding views)

struct OnboardingAssetImage: View {
    let name: String
    var fallbackColors: [Color] = [Color(red: 0.20, green: 0.20, blue: 0.25), Color(red: 0.15, green: 0.15, blue: 0.20)]
    var contentMode: ContentMode = .fill

    var body: some View {
        if UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            LinearGradient(
                colors: fallbackColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Flow model

@MainActor
final class OnboardingFlowModel: ObservableObject {
    @Published var step: OnboardingStep = .hero
    @Published var gender: OnboardingGender?
    @Published var country: OnboardingCountry?
    @Published var selectedDemoIndex: Int?

    let onComplete: () -> Void

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var demoItems: [OnboardingDemoItem] {
        gender == .male ? OnboardingDemoItem.male : OnboardingDemoItem.female
    }

    func advance() {
        let all = OnboardingStep.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else {
            onComplete(); return
        }
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            step = all[idx + 1]
        }
    }

    func advance(to target: OnboardingStep) {
        withAnimation(.spring(response: 0.52, dampingFraction: 0.84)) {
            step = target
        }
    }

    func complete() { onComplete() }
}
