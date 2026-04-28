//
//  SaveSession.swift
//  NHSEiOS
//
//  Observable wrapper around the loaded HorizonSave so SwiftUI views can
//  react to load/save state. Edits are pushed back into the underlying
//  HorizonSave structures and committed on export.
//

import Foundation
import SwiftUI

@MainActor
public final class SaveSession: ObservableObject {

    public enum Status: Equatable {
        case idle
        case loading
        case loaded
        case error(String)
    }

    @Published public private(set) var status: Status = .idle

    /// Last loaded save (decrypted, in memory).
    @Published public private(set) var save: HorizonSave?

    /// User-facing notes about whether re-encryption is supported.
    @Published public private(set) var notes: [String] = []

    /// Hash recompute status from the most recent save attempt.
    @Published public private(set) var lastSkippedRehash: [String] = []

    public init() {}

    // MARK: - Loading

    /// Load a save folder by URL. Caller is responsible for security-scoped access.
    public func load(folderURL: URL) {
        status = .loading
        notes = []
        save  = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let s = try HorizonSave.fromFolder(folderURL)
                let n = await Self.computeNotes(for: s)
        status = .loading
        notes = []
        save  = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let s = try HorizonSave.fromZip(zipURL)
                let n = await Self.computeNotes(for: s)
                await MainActor.run {
                    guard let self else { return }
                    self.save = s
                    self.notes = n
                    self.status = .loaded
                }
            } catch {
                let msg = (error as? CustomStringConvertible)?.description ?? error.localizedDescription
                await MainActor.run {
                    guard let self else { return }
                    self.status = .error(msg)
                }
            }
        }
    }

    public func unload() {
        save = nil
        notes = []
        status = .idle
    }

    // MARK: - Mutation entry-points (used by editor views)

    /// Force a SwiftUI update after directly mutating the underlying save.
    public func bumpVersion() {
        objectWillChange.send()
    }

    // MARK: - Saving

    /// Re-hash everything that has a hash table and re-encrypt. Returns the
    /// repacked save written to a fresh in-memory zip.
    public func exportZip(seed: UInt32 = 0xDEADBEEF) throws -> Data {
        guard let s = save else {
            throw NSError(domain: "NHSE", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No save loaded."])
        }
        let skipped = s.rehashAll()
        lastSkippedRehash = skipped

        // Build a fresh in-memory archive and re-encrypt every pair into it.
        let outArchive = ZipArchive()
        let outProvider = ZipSaveFileProvider(archive: outArchive, rootPrefix: "")
        try writeAll(save: s, into: outProvider, seed: seed)
        return try outArchive.write()
    }

    /// Write all files (re-encrypted) into the given provider.
    private func writeAll(save: HorizonSave,
                          into provider: ISaveFileProvider,
                          seed: UInt32) throws
    {
        // Main goes at the archive root.
        try writePair(save.main, into: provider, seed: seed)
        // Each player goes into its named subdirectory.
        for player in save.players {
            let sub = provider.subProvider(player.directoryName)
            for pair in player.allPairs {
                try writePair(pair, into: sub, seed: seed)
            }
        }
        try provider.flush()
    }

    private func writePair(_ pair: EncryptedFilePair,
                           into provider: ISaveFileProvider,
                           seed: UInt32) throws
    {
        let plaintext = [UInt8](pair.data)
        let result = try Encryption.encrypt(data: plaintext,
                                            seed: seed,
                                            versionData: pair.header)
        try provider.writeFile(pair.nameData, data: Data(result.data))
        try provider.writeFile(pair.nameHeader, data: result.header)
    }

    // MARK: - Notes builder

    private static func computeNotes(for save: HorizonSave) -> [String] {
        var notes: [String] = []
        notes.append("Detected revision: \(save.main.revision.displayName)")
        if save.main.offsets == nil {
            notes.append("⚠️ No offset table for this revision — the app loads it read-only. Editing requires 2.0.0+.")
        }
        if !save.main.canRehash {
            notes.append("⚠️ No Murmur3 hash table for main.dat at size \(save.main.data.count). Re-encrypted output may fail integrity checks.")
        }
        let bad = save.main.invalidHashes()
        if !bad.isEmpty {
            notes.append("ℹ️ Loaded save has \(bad.count) pre-existing main.dat hash mismatch(es). They will be recomputed on export.")
        }
        return notes
    }
}
