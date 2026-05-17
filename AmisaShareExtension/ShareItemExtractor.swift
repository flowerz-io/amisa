import Foundation
import UIKit
import UniformTypeIdentifiers

/// Extraction d’éléments depuis le sheet de partage — journaux détaillés en cas d’échec.
enum ShareItemExtractor {
    static func logItemProvider(_ provider: NSItemProvider, context: String) {
        let ids = provider.registeredTypeIdentifiers
        NSLog("[ShareItemExtractor] %@ — NSItemProvider registeredTypeIdentifiers count=%lu ids=%@",
              context, ids.count, ids.joined(separator: ", "))
        for id in ids {
            if let ut = UTType(id) {
                NSLog("[ShareItemExtractor] %@ — UTType identifier=%@ preferredMIMEType=%@ conformsTo.publicURL=%@ conformsTo.image=%@",
                      context,
                      ut.identifier,
                      ut.preferredMIMEType ?? "nil",
                      ut.conforms(to: .url) ? "yes" : "no",
                      ut.conforms(to: .image) ? "yes" : "no")
            } else {
                NSLog("[ShareItemExtractor] %@ — identifier=%@ (UTType non résolu)", context, id)
            }
        }
        NSLog("[ShareItemExtractor] %@ — suggestedName=%@ hasItemConformingToTypeIdentifier(public.url)=%@ public.image=%@",
              context,
              provider.suggestedName ?? "nil",
              provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) ? "yes" : "no",
              provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) ? "yes" : "no")
    }

    static func logExtractionFailure(_ error: Error, context: String) {
        NSLog("[ShareItemExtractor] ÉCHEC %@ — error=%@", context, String(describing: error))
    }
}
