//
//  HorizonSave.swift
//  NHSEiOS
//
//  Top-level container holding the MainSave + every Player subdirectory.
//  Port of NHSE.Core/Save/Meta/HorizonSave.cs.
//

import Foundation

public final class HorizonSave {

    public let provider: ISaveFileProvider

    public let main: MainSave
    public let players: [Player]

    public init(provider: ISaveFileProvider) throws {
        self.provider = provider
        self.main = try MainSave(provider: provider)
        self.players = try Player.readMany(provider: provider)
    }

    /// Convenience: load from a folder URL.
    public static func fromFolder(_ url: URL) throws -> HorizonSave {
        let provider = FolderSaveFileProvider(rootURL: url)
        return try HorizonSave(provider: provider)
    }

    /// Convenience: load from a zip URL.
    public static func fromZip(_ url: URL) throws -> HorizonSave {
        let provider = try ZipSaveFileProvider.load(from: url)
        return try HorizonSave(provider: provider)
    }

    /// All file pairs in the save.
    public var allPairs: [EncryptedFilePair] {
        var out: [EncryptedFilePair] = [main]
        for p in players { out.append(contentsOf: p.allPairs) }
        return out
    }

    /// Recompute every supported file's Murmur3 hashes.
    /// Returns the names of files that had no hash table (and so were skipped).
    @discardableResult
    public func rehashAll() -> [String] {
        var skipped: [String] = []
        for pair in allPairs {
            if !pair.hash() { skipped.append(pair.nameData) }
        }
        return skipped
    }

    /// Re-encrypt and write every file pair using `seed` as the encryption seed.
    /// Caller is responsible for calling `rehashAll()` first if mutations were made.
    public func save(seed: UInt32) throws {
        for pair in allPairs {
            try pair.save(seed: seed)
        }
        try provider.flush()
    }

    /// Returns true if every file pair's plaintext size matches the size table
    /// for the detected revision (basic sanity check).
    public func validateSizes() -> Bool {
        let idx = RevisionTable.index(of: main.info)
        guard idx >= 0,
              UInt32(main.data.count) == RevisionTable.mainDatSizes[idx]
        else { return false }
        return true
    }

    /// Useful for the UI: a single sentence summarising the save.
    public func summary() -> String {
        let firstPlayer = players.first?.personal.playerName ?? "—"
        let town        = players.first?.personal.townName   ?? "—"
        return "\(town) — \(firstPlayer) (\(main.revision.displayName))"
    }
}
