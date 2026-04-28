//
//  MainSave.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Files/MainSave.cs (subset).
//

import Foundation

public enum Hemisphere: UInt8 {
    case northern = 0
    case southern = 1

    public var displayName: String {
        switch self {
        case .northern: return "Northern"
        case .southern: return "Southern"
        }
    }
}

public final class MainSave: EncryptedFilePair {

    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: "main")
    }

    public var revision: SaveRevision {
        let idx = RevisionTable.index(of: info)
        if idx >= 0, let rev = SaveRevision(rawValue: idx) { return rev }
        return .v3_0_2
    }

    public var offsets: MainSaveOffsets? {
        return MainSaveOffsets.forRevision(revision)
    }

    public var hemisphere: Hemisphere? {
        get {
            guard let o = offsets else { return nil }
            return Hemisphere(rawValue: data.readU8(at: o.weatherArea))
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            data.writeU8(v.rawValue, at: o.weatherArea)
        }
    }

    public var airportThemeColor: UInt8? {
        get {
            guard let o = offsets else { return nil }
            return data.readU8(at: o.airportThemeColor)
        }
        set {
            guard let o = offsets, let v = newValue else { return }
            data.writeU8(v, at: o.airportThemeColor)
        }
    }

    /// Recycle bin contents (40 items).
    public var recycleBin: [Item] {
        get {
            guard let o = offsets else { return [] }
            return Item.readArray(from: data,
                                  at: o.lostItemBox,
                                  count: MainSaveOffsets.recycleBinCount)
        }
        set {
            guard let o = offsets else { return }
            let n = min(newValue.count, MainSaveOffsets.recycleBinCount)
            for i in 0..<n {
                newValue[i].write(to: &data, at: o.lostItemBox + (i * Item.size))
            }
        }
    }

    // MARK: - Villagers

    public func villager(at index: Int) -> Villager? {
        guard let o = offsets,
              index >= 0,
              index < MainSaveOffsets.villagerCount
        else { return nil }
        let off = o.animal + (index * o.villagerSize)
        return Villager(data: data, baseOffset: off)
    }

    public func setVillager(_ villager: Villager, at index: Int) {
        guard let o = offsets,
              index >= 0,
              index < MainSaveOffsets.villagerCount
        else { return }
        let off = o.animal + (index * o.villagerSize)
        villager.write(to: &data, baseOffset: off)
    }

    public func allVillagers() -> [Villager] {
        var out: [Villager] = []
        for i in 0..<MainSaveOffsets.villagerCount {
            if let v = villager(at: i) {
                out.append(v)
            }
        }
        return out
    }
}
