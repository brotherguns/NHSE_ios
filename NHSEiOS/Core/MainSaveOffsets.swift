//
//  MainSaveOffsets.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Offsets/MainSaveOffsets*.cs (subset, 2.0/3.0).
//

import Foundation

public struct MainSaveOffsets {
    public static let playerCount: Int = 8
    public static let villagerCount: Int = 10
    public static let recycleBinCount: Int = 40

    public let animal: Int           // Villager array start
    public let villagerSize: Int     // Villager2.SIZE
    public let weatherArea: Int      // hemisphere byte
    public let lostItemBox: Int      // recycle bin
    public let airportThemeColor: Int

    /// Returns nil when revision is unsupported for editing.
    public static func forRevision(_ rev: SaveRevision) -> MainSaveOffsets? {
        switch rev.rawValue {
        case SaveRevision.v2_0_0.rawValue ... SaveRevision.v2_0_8.rawValue:
            return v20
        case SaveRevision.v3_0_0.rawValue ... SaveRevision.v3_0_2.rawValue:
            return v30
        default:
            return nil
        }
    }

    // MARK: - Villager structure (Villager2)

    public static let villager2Size = 0x13230

    // MARK: - Revision tables

    private static let v20: MainSaveOffsets = {
        let gSaveLandStart = 0x110
        return MainSaveOffsets(
            animal: gSaveLandStart + 0x10,
            villagerSize: villager2Size,
            weatherArea: gSaveLandStart + 0x1e35f0 + 0x14,
            lostItemBox: 0x547520 + 0x3726c0,
            airportThemeColor: gSaveLandStart + 0x5437c8
        )
    }()

    private static let v30: MainSaveOffsets = {
        let gSaveLandStart = 0x110
        return MainSaveOffsets(
            animal: gSaveLandStart + 0x10,
            villagerSize: villager2Size,
            weatherArea: gSaveLandStart + 0x1e35f0 + 0x14,
            lostItemBox: 0x5b3d50 + 0x3c4fc0,
            airportThemeColor: gSaveLandStart + 0x575cb0
        )
    }()
}
