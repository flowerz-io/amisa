//
//  LegacyAmisaStorageMigration.swift
//
//  Migration unique au premier lancement après rebranding : UserDefaults standard,
//  conteneur App Group et fichiers partagés (anciens identifiants Balibu → Amisa).
//

import Foundation

enum LegacyAmisaStorageMigration {
    static let legacyAppGroupIdentifier = "group.flowerz.io.Amisa"
    static let currentAppGroupIdentifier = "group.flowerz.io.Amisa"

    private static let migratedStandardDefaultsKey = "amisa.migratedStandardDefaultsFromBalibu"
    private static let migratedAppGroupKey = "amisa.migratedAppGroupFromBalibu"

    static func runAtLaunch() {
        migrateStandardUserDefaultsIfNeeded()
        migrateAppGroupFilesystemAndDefaultsIfNeeded()
    }

    private static func migrateStandardUserDefaultsIfNeeded() {
        let std = UserDefaults.standard
        guard !std.bool(forKey: migratedStandardDefaultsKey) else { return }
        defer { std.set(true, forKey: migratedStandardDefaultsKey) }

        for (key, value) in std.dictionaryRepresentation() where key.hasPrefix("amisa.") {
            let newKey = "amisa." + key.dropFirst("amisa.".count)
            if std.object(forKey: newKey) == nil {
                std.set(value, forKey: newKey)
            }
        }
    }

    private static func migrateAppGroupFilesystemAndDefaultsIfNeeded() {
        let std = UserDefaults.standard
        guard !std.bool(forKey: migratedAppGroupKey) else { return }

        let fm = FileManager.default
        guard let oldBase = fm.containerURL(forSecurityApplicationGroupIdentifier: legacyAppGroupIdentifier),
              let newBase = fm.containerURL(forSecurityApplicationGroupIdentifier: currentAppGroupIdentifier)
        else {
            std.set(true, forKey: migratedAppGroupKey)
            return
        }

        let dirs = ["SharedImages", "SessionResults", "ContinuitySnapshots"]
        for dir in dirs {
            let src = oldBase.appendingPathComponent(dir)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = newBase.appendingPathComponent(dir)
            try? fm.createDirectory(at: dst, withIntermediateDirectories: true)
            guard let items = try? fm.contentsOfDirectory(atPath: src.path) else { continue }
            for item in items {
                let s = src.appendingPathComponent(item)
                let d = dst.appendingPathComponent(item)
                if !fm.fileExists(atPath: d.path) {
                    try? fm.copyItem(at: s, to: d)
                }
            }
        }

        guard let oldUD = UserDefaults(suiteName: legacyAppGroupIdentifier),
              let newUD = UserDefaults(suiteName: currentAppGroupIdentifier)
        else {
            std.set(true, forKey: migratedAppGroupKey)
            return
        }

        for (key, value) in oldUD.dictionaryRepresentation() {
            if key.hasPrefix("Apple") || key.hasPrefix("NS") || key == "AKTemplateVersion" { continue }
            let destKey: String
            if key.hasPrefix("amisa.") {
                destKey = "amisa." + key.dropFirst("amisa.".count)
            } else {
                destKey = key
            }
            if newUD.object(forKey: destKey) == nil {
                newUD.set(value, forKey: destKey)
            }
        }
        newUD.synchronize()
        std.set(true, forKey: migratedAppGroupKey)
    }
}
