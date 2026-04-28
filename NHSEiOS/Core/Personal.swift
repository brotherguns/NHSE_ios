//
//  Personal.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Files/Personal.cs (essentials).
//

import Foundation

public final class Personal: EncryptedFilePair {

    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: "personal")
    }

    /// Detected save revision based on the parsed FileHeaderInfo.
    public var revision: SaveRevision {
        let idx = RevisionTable.index(of: info)
        if idx >= 0, let rev = SaveRevision(rawValue: idx) { return rev }
        return .v3_0_2 // best-guess fallback
    }

    /// Per-revision offset table; nil for unsupported revisions.
    public var offsets: PersonalOffsets? {
        return PersonalOffsets.forRevision(revision)
    }

    // MARK: - Town / Player identity

    public var townID: UInt32 {
        get {
            guard let o = offsets else { return 0 }
            return data.readU32LE(at: o.personalId)
        }
        set {
            guard let o = offsets else { return }
            data.writeU32LE(newValue, at: o.personalId)
        }
    }

    public var townName: String {
        get {
            guard let o = offsets else { return "" }
            return StringUtil.getString(from: data, at: o.personalId + 0x04, maxCharCount: 10)
        }
        set {
            guard let o = offsets else { return }
            let bytes = StringUtil.getBytes(newValue, maxCharCount: 10)
            data.replaceRange(at: o.personalId + 0x04, length: 20, with: bytes)
        }
    }

    public var playerID: UInt32 {
        get {
            guard let o = offsets else { return 0 }
            return data.readU32LE(at: o.personalId + 0x1C)
        }
        set {
            guard let o = offsets else { return }
            data.writeU32LE(newValue, at: o.personalId + 0x1C)
        }
    }

    public var playerName: String {
        get {
            guard let o = offsets else { return "" }
            return StringUtil.getString(from: data, at: o.personalId + 0x20, maxCharCount: 10)
        }
        set {
            guard let o = offsets else { return }
            let bytes = StringUtil.getBytes(newValue, maxCharCount: 10)
            data.replaceRange(at: o.personalId + 0x20, length: 20, with: bytes)
        }
    }

    /// 24-byte (4 + 20) town identity (id + name).
    public func getTownIdentity() -> Data? {
        guard let o = offsets else { return nil }
        return data.slice(at: o.personalId, length: 4 + 20)
    }

    /// 24-byte (4 + 20) player identity (id + name).
    public func getPlayerIdentity() -> Data? {
        guard let o = offsets else { return nil }
        return data.slice(at: o.personalId + 0x1C, length: 4 + 20)
    }

    // MARK: - Currencies (encrypted)

    public var wallet: EncryptedInt32? {
        get {
            guard let o = offsets else { return nil }
            return EncryptedInt32.read(from: data, at: o.wallet)
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            v.write(to: &data, at: o.wallet)
        }
    }

    public var bank: EncryptedInt32? {
        get {
            guard let o = offsets else { return nil }
            return EncryptedInt32.read(from: data, at: o.bank)
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            v.write(to: &data, at: o.bank)
        }
    }

    public var nookMiles: EncryptedInt32? {
        get {
            guard let o = offsets else { return nil }
            return EncryptedInt32.read(from: data, at: o.nowPoint)
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            v.write(to: &data, at: o.nowPoint)
        }
    }

    public var totalNookMiles: EncryptedInt32? {
        get {
            guard let o = offsets else { return nil }
            return EncryptedInt32.read(from: data, at: o.totalPoint)
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            v.write(to: &data, at: o.totalPoint)
        }
    }

    // MARK: - Inventory

    /// Slots 1..20 (the "Pocket").
    public var pocket: [Item] {
        get {
            guard let o = offsets else { return [] }
            return Item.readArray(from: data, at: o.pockets2,
                                  count: PersonalOffsets.pockets2Count)
        }
        set {
            guard let o = offsets else { return }
            // Match underlying disk size — only writes what we have.
            let count = min(newValue.count, PersonalOffsets.pockets2Count)
            for i in 0..<count {
                newValue[i].write(to: &data, at: o.pockets2 + (i * Item.size))
            }
        }
    }

    /// Slots 21..40 (the unlocked "Bag").
    public var bag: [Item] {
        get {
            guard let o = offsets else { return [] }
            return Item.readArray(from: data, at: o.pockets1,
                                  count: PersonalOffsets.pockets1Count)
        }
        set {
            guard let o = offsets else { return }
            let count = min(newValue.count, PersonalOffsets.pockets1Count)
            for i in 0..<count {
                newValue[i].write(to: &data, at: o.pockets1 + (i * Item.size))
            }
        }
    }

    /// The home storage chest.
    public var itemChest: [Item] {
        get {
            guard let o = offsets else { return [] }
            return Item.readArray(from: data, at: o.itemChest, count: o.itemChestCount)
        }
        set {
            guard let o = offsets else { return }
            let count = min(newValue.count, o.itemChestCount)
            for i in 0..<count {
                newValue[i].write(to: &data, at: o.itemChest + (i * Item.size))
            }
        }
    }
}
