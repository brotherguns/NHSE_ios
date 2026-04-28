//
//  Player.swift
//  NHSEiOS
//
//  Bundle of file pairs for one Villager# subdirectory.
//  Port of NHSE.Core/Save/Meta/Player.cs.
//

import Foundation

public final class Player {

    public let directoryName: String

    public let personal: Personal
    public let postBox:  PostBox
    public let photo:    PhotoStudioIsland
    public let profile:  Profile
    public let whereAreN: WhereAreN?

    /// All decrypted file pairs belonging to this player.
    public var allPairs: [EncryptedFilePair] {
        var out: [EncryptedFilePair] = [personal, postBox, photo, profile]
        if let w = whereAreN { out.append(w) }
        return out
    }

    /// Returns the discovered `Villager*` directories (sorted) inside `provider`.
    public static func playerDirectories(in provider: ISaveFileProvider) -> [String] {
        return provider.directories(matching: "Villager*")
    }

    /// Load every `Villager*` subdirectory found in `provider`.
    public static func readMany(provider: ISaveFileProvider) throws -> [Player] {
        let dirs = playerDirectories(in: provider)
        var out: [Player] = []
        out.reserveCapacity(dirs.count)
        for d in dirs {
            let sub = provider.subProvider(d)
            out.append(try Player(provider: sub, directoryName: d))
        }
        return out
    }

    public init(provider: ISaveFileProvider, directoryName: String) throws {
        self.directoryName = directoryName

        self.personal = try Personal(provider: provider)
        self.postBox  = try PostBox(provider: provider)
        self.photo    = try PhotoStudioIsland(provider: provider)
        self.profile  = try Profile(provider: provider)

        if EncryptedFilePair.exists(in: provider, name: WhereAreN.fileName) {
            self.whereAreN = try WhereAreN(provider: provider)
        } else {
            self.whereAreN = nil
        }
    }
}
