//
//  EncryptedFilePair.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Meta/EncryptedFilePair.cs.
//  Each save file is stored as a pair: <name>.dat (data) and <name>Header.dat
//  (encryption key material in bytes 0x100..0x300, plus version metadata in
//  bytes 0..0x100).
//

import Foundation

public class EncryptedFilePair {

    public let provider: ISaveFileProvider
    public let nameData: String
    public let nameHeader: String

    /// Decrypted plaintext of <name>.dat. Mutable.
    public internal(set) var data: Data

    /// Original encrypted header bytes. We reuse `header[0..0x100]` as the
    /// "version data" when re-encrypting.
    public internal(set) var header: Data

    /// Parsed FileHeaderInfo from the first 0x40 bytes of plaintext.
    public let info: FileHeaderInfo

    public static func exists(in provider: ISaveFileProvider, name: String) -> Bool {
        return provider.fileExists("\(name).dat") && provider.fileExists("\(name)Header.dat")
    }

    public init(provider: ISaveFileProvider, name: String) throws {
        self.provider   = provider
        self.nameData   = "\(name).dat"
        self.nameHeader = "\(name)Header.dat"

        let hd = try provider.readFile(nameHeader)
        var md = try provider.readFile(nameData)

        var bytes = [UInt8](md)
        try Encryption.decrypt(headerData: hd, encData: &bytes)
        md = Data(bytes)

        self.data = md
        self.header = hd

        guard let info = FileHeaderInfo(decrypted: md) else {
            throw EncryptedFilePairError.headerParseFailed(name: name)
        }
        self.info = info
    }

    /// Re-encrypt `data` with a fresh header derived from `seed`, then write both.
    public func save(seed: UInt32) throws {
        let plaintextBytes = [UInt8](data)
        let result = try Encryption.encrypt(data: plaintextBytes,
                                            seed: seed,
                                            versionData: header)
        try provider.writeFile(nameData, data: Data(result.data))
        try provider.writeFile(nameHeader, data: result.header)
        // Update local header to the freshly written one (so subsequent saves
        // continue from the same epoch).
        header = result.header
    }

    /// Recompute Murmur3 hashes for every region defined for this file's size.
    /// Returns true if hash details were available; false otherwise (in which
    /// case the data was not modified and `save()` should not be called).
    @discardableResult
    public func hash() -> Bool {
        guard let details = HashRegionTable.lookup(fileName: nameData, size: data.count) else {
            return false
        }
        for region in details.regions {
            let region_data = data.subdata(in: region.beginOffset..<region.endOffset)
            let h = Murmur3.hash(region_data)
            data.writeU32LE(h, at: region.hashOffset)
        }
        return true
    }

    /// Returns hash regions that currently fail validation.
    public func invalidHashes() -> [FileHashRegion] {
        guard let details = HashRegionTable.lookup(fileName: nameData, size: data.count) else {
            return []
        }
        var bad: [FileHashRegion] = []
        for region in details.regions {
            let stored   = data.readU32LE(at: region.hashOffset)
            let region_data = data.subdata(in: region.beginOffset..<region.endOffset)
            let computed = Murmur3.hash(region_data)
            if stored != computed { bad.append(region) }
        }
        return bad
    }

    /// True when we have a hash table for this file (safe to re-encrypt + save).
    public var canRehash: Bool {
        return HashRegionTable.lookup(fileName: nameData, size: data.count) != nil
    }
}

public enum EncryptedFilePairError: Error, CustomStringConvertible {
    case headerParseFailed(name: String)

    public var description: String {
        switch self {
        case .headerParseFailed(let n): return "Failed to parse FileHeaderInfo for '\(n)'"
        }
    }
}
