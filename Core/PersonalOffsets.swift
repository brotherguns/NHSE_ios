//
//  PersonalOffsets.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Offsets/PersonalOffsets*.cs (subset).
//
//  We ship offset tables for revisions 2.0.x and 3.0.x — these cover all
//  saves dumped from the latest two major versions of NH. Older saves load
//  read-only.
//

import Foundation

public struct PersonalOffsets {

    public let personalId: Int
    public let wallet: Int
    public let bank: Int
    public let nowPoint: Int        // Nook Miles (current)
    public let totalPoint: Int      // Nook Miles (total earned)
    public let pockets1: Int        // Bag (slots 21-40)
    public let pockets2: Int        // Pocket (slots 1-20)
    public let itemChest: Int
    public let itemChestCount: Int

    public static let pockets1Count: Int = 20
    public static let pockets2Count: Int = 20

    /// Returns nil when the revision isn't supported for editing.
    public static func forRevision(_ rev: SaveRevision) -> PersonalOffsets? {
        switch rev.rawValue {
        case SaveRevision.v2_0_0.rawValue ... SaveRevision.v2_0_8.rawValue:
            return v20
        case SaveRevision.v3_0_0.rawValue ... SaveRevision.v3_0_2.rawValue:
            return v30
        default:
            return nil
        }
    }

    // MARK: - Tables

    /// PersonalOffsets20 (NHSE):
    ///   Player        = 0x110
    ///   PersonalId    = Player + 0xAFA8
    ///   PlayerOther   = 0x36a50
    ///   Pockets1      = PlayerOther + 0x10
    ///   Pockets2      = Pockets1 + (8 * 20) + 0x18
    ///   Wallet        = Pockets2 + (8 * 20) + 0x18
    ///   ItemChest     = PlayerOther + 0x18C
    ///   Bank          = PlayerOther + 0x24afc
    ///   ItemChestCount = 5000
    private static let v20: PersonalOffsets = {
        let player = 0x110
        let personalId = player + 0xAFA8
        let gSaveLifeSupport = player + 0xBFE0
        let nowPoint = gSaveLifeSupport + 0x5498
        let totalPoint = nowPoint + 8

        let playerOther = 0x36a50
        let pockets1 = playerOther + 0x10
        let pockets2 = pockets1 + (8 * 20) + 0x18
        let wallet   = pockets2 + (8 * 20) + 0x18
        let itemChest = playerOther + 0x18C
        let bank      = playerOther + 0x24afc
        return PersonalOffsets(
            personalId: personalId,
            wallet: wallet,
            bank: bank,
            nowPoint: nowPoint,
            totalPoint: totalPoint,
            pockets1: pockets1,
            pockets2: pockets2,
            itemChest: itemChest,
            itemChestCount: 5000
        )
    }()

    /// PersonalOffsets30 (NHSE):
    ///   PersonalId    = Player + 0xc138
    ///   PlayerOther   = 0x37be0
    ///   ItemChestCount = 0x11944 / 8 = 9000
    ///   Bank          = PlayerOther + 0x2d69c
    private static let v30: PersonalOffsets = {
        let player = 0x110
        let personalId = player + 0xc138
        let gSaveLifeSupport = player + 0xd170
        let nowPoint = gSaveLifeSupport + 0x5498
        let totalPoint = nowPoint + 8

        let playerOther = 0x37be0
        let pockets1 = playerOther + 0x10
        let pockets2 = pockets1 + (8 * 20) + 0x18
        let wallet   = pockets2 + (8 * 20) + 0x18
        let itemChest = playerOther + 0x18C
        let bank      = playerOther + 0x2d69c
        return PersonalOffsets(
            personalId: personalId,
            wallet: wallet,
            bank: bank,
            nowPoint: nowPoint,
            totalPoint: totalPoint,
            pockets1: pockets1,
            pockets2: pockets2,
            itemChest: itemChest,
            itemChestCount: 0x11944 / 8 // 9000
        )
    }()
}
