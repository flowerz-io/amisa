//
//  Color+Amisa.swift
//  Raccourcis vers la palette marque (SwiftUI + UIKit).
//

import SwiftUI
import UIKit

extension Color {
    static var amisaPrimary: Color { BrandColors.primaryRed }
    static var amisaSecondary: Color { BrandColors.secondaryOrange }
}

extension UIColor {
    static var amisaPrimary: UIColor { UIColor(BrandColors.primaryRed) }
    static var amisaSecondary: UIColor { UIColor(BrandColors.secondaryOrange) }
}
