//
//  Villager.swift
//  NHSEiOS
//
//  Lightweight read/write surface for the Villager2 structure (post-1.5).
//  Only the bytes we actually edit are exposed — the rest is preserved verbatim.
//

import Foundation

public enum VillagerPersonality: UInt8, CaseIterable {
    case lazy        = 0
    case jock        = 1
    case cranky      = 2
    case smug        = 3
    case normal      = 4
    case peppy       = 5
    case snooty      = 6
    case bigSister   = 7
    case unknown     = 0xFF

    public var displayName: String {
        switch self {
        case .lazy:      return "Lazy"
        case .jock:      return "Jock"
        case .cranky:    return "Cranky"
        case .smug:      return "Smug"
        case .normal:    return "Normal"
        case .peppy:     return "Peppy"
        case .snooty:    return "Snooty"
        case .bigSister: return "Big Sister"
        case .unknown:   return "Unknown"
        }
    }
}

public struct Villager {

    /// The villager's data is sliced out as a private buffer at construction
    /// time so the view layer can hold a value without retaining the entire
    /// MainSave Data.
    public var raw: Data

    public init(data: Data, baseOffset: Int) {
        self.raw = data.slice(at: baseOffset, length: MainSaveOffsets.villager2Size)
    }

    public init(raw: Data) {
        self.raw = raw
    }

    public func write(to data: inout Data, baseOffset: Int) {
        data.replaceRange(at: baseOffset, length: MainSaveOffsets.villager2Size, with: raw)
    }

    // 0x00 species, 0x01 variant, 0x02 personality.
    public var species: UInt8 {
        get { raw.readU8(at: 0x00) }
        set { raw.writeU8(newValue, at: 0x00) }
    }

    public var variant: UInt8 {
        get { raw.readU8(at: 0x01) }
        set { raw.writeU8(newValue, at: 0x01) }
    }

    public var personality: VillagerPersonality {
        get { VillagerPersonality(rawValue: raw.readU8(at: 0x02)) ?? .unknown }
        set { raw.writeU8(newValue.rawValue, at: 0x02) }
    }

    /// Indicates whether this slot is occupied. Empty slots use 0xFF / 0x00 species.
    public var isPresent: Bool {
        return species != 0xFF && species != 0x00
    }

    /// Internal name (species + variant index in NH parlance), unparsed; we
    /// don't ship the full localisation table in this MVP.
    public var internalCode: String {
        return String(format: "%02X%02X", species, variant)
    }
}
