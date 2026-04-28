//
//  Item.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Structures/Item/Item.cs (8-byte item).
//
//    [0..2) ItemId         (u16 LE)
//    [2]    SystemParam    (rotation, buried flag, dropped flag…)
//    [3]    AdditionalParam (wrapping flags)
//    [4..8) FreeParam      (i32 LE — variant/count/etc.)
//

import Foundation

public struct Item: Equatable {
    public static let size: Int = 8
    public static let none: UInt16 = 0xFFFE
    public static let extensionMarker: UInt16 = 0xFFFD
    public static let fieldItemMin: UInt16 = 60_000
    public static let messageBottle: UInt16 = 0x16A1
    public static let diyRecipe: UInt16 = 0x16A2

    public var itemId: UInt16
    public var systemParam: UInt8
    public var additionalParam: UInt8
    public var freeParam: Int32

    public init(itemId: UInt16 = Item.none,
                systemParam: UInt8 = 0,
                additionalParam: UInt8 = 0,
                freeParam: Int32 = 0)
    {
        self.itemId = itemId
        self.systemParam = systemParam
        self.additionalParam = additionalParam
        self.freeParam = freeParam
    }

    public static func read(from data: Data, at offset: Int) -> Item {
        let id  = data.readU16LE(at: offset)
        let sp  = data.readU8(at: offset + 2)
        let ap  = data.readU8(at: offset + 3)
        let fp  = Int32(bitPattern: data.readU32LE(at: offset + 4))
        return Item(itemId: id, systemParam: sp, additionalParam: ap, freeParam: fp)
    }

    public func write(to data: inout Data, at offset: Int) {
        data.writeU16LE(itemId, at: offset)
        data.writeU8(systemParam, at: offset + 2)
        data.writeU8(additionalParam, at: offset + 3)
        data.writeU32LE(UInt32(bitPattern: freeParam), at: offset + 4)
    }

    /// Read `count` consecutive items from `data` starting at `offset`.
    public static func readArray(from data: Data, at offset: Int, count: Int) -> [Item] {
        var out = [Item]()
        out.reserveCapacity(count)
        for i in 0..<count {
            out.append(read(from: data, at: offset + (i * size)))
        }
        return out
    }

    /// Write `items` consecutively into `data` starting at `offset`.
    public static func writeArray(_ items: [Item], to data: inout Data, at offset: Int) {
        for (i, item) in items.enumerated() {
            item.write(to: &data, at: offset + (i * size))
        }
    }

    // MARK: - Convenience flag accessors

    public var isEmpty: Bool { itemId == Item.none }

    /// 0–3, low two bits of SystemParam.
    public var rotation: Int {
        get { Int(systemParam & 0x3) }
        set { systemParam = (systemParam & ~0x3) | UInt8(newValue & 0x3) }
    }

    public var isBuried: Bool {
        get { (systemParam & 0x04) != 0 }
        set { systemParam = (systemParam & ~0x04) | (newValue ? 0x04 : 0) }
    }

    public var isDropped: Bool {
        get { (systemParam & 0x20) != 0 }
        set { systemParam = (systemParam & ~0x20) | (newValue ? 0x20 : 0) }
    }
}
