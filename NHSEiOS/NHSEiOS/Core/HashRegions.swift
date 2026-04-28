//
//  HashRegions.swift
//  NHSEiOS
//
//  Per-revision Murmur3 hash regions for each save file.
//  Source: NHSE.Core/Hashing/FileHashRevision.cs (REV_100..REV_300).
//
//  A FileHashRegion describes a single hash entry: the 4-byte hash lives at
//  `hashOffset`, and covers the bytes [hashOffset+4 ..< hashOffset+4+length).
//

import Foundation

public struct FileHashRegion: Equatable {
    public let hashOffset: Int
    public let length: Int
    public init(_ hashOffset: Int, _ length: Int) {
        self.hashOffset = hashOffset
        self.length = length
    }
    public var beginOffset: Int { hashOffset + 4 }
    public var endOffset:   Int { beginOffset + length }
}

public struct FileHashDetails {
    public let fileName: String
    public let fileSize: UInt32
    public let regions: [FileHashRegion]
}

/// Look up hash regions for a given save filename + decrypted plaintext size.
/// We dispatch on filename and size; the size determines which patch revision
/// we are dealing with.
public enum HashRegionTable {

    // MARK: - Filenames (match EncryptedFilePair: "<name>.dat")
    public static let mainFile      = "main.dat"
    public static let personalFile  = "personal.dat"
    public static let postboxFile   = "postbox.dat"
    public static let photoFile     = "photo_studio_island.dat"
    public static let profileFile   = "profile.dat"
    public static let whereArenFile = "wherearen.dat"

    /// Returns hash details for (filename, decrypted size). nil if unsupported.
    public static func lookup(fileName: String, size: Int) -> FileHashDetails? {
        switch fileName {
        case mainFile:      return mainTable[UInt32(size)]
        case personalFile:  return personalTable[UInt32(size)]
        case postboxFile:   return postboxTable[UInt32(size)]
        case photoFile:     return photoTable[UInt32(size)]
        case profileFile:   return profileTable[UInt32(size)]
        case whereArenFile: return whereArenTable[UInt32(size)]
        default:            return nil
        }
    }

    // MARK: - main.dat tables

    /// Constructed sparingly — we only ship the most common revisions to keep
    /// the binary small. For older revisions, hash recompute is best-effort:
    /// loading still works, but the app will refuse to re-encrypt unless we
    /// have hash details for that exact size.
    private static let mainTable: [UInt32: FileHashDetails] = [
        // 1.0.0
        0xAC0938: FileHashDetails(fileName: mainFile, fileSize: 0xAC0938, regions: [
            FileHashRegion(0x000108, 0x1D6D4C),
            FileHashRegion(0x1D6E58, 0x323384),
            FileHashRegion(0x4FA2E8, 0x035AC4),
            FileHashRegion(0x52FDB0, 0x03607C),
            FileHashRegion(0x565F38, 0x035AC4),
            FileHashRegion(0x59BA00, 0x03607C),
            FileHashRegion(0x5D1B88, 0x035AC4),
            FileHashRegion(0x607650, 0x03607C),
            FileHashRegion(0x63D7D8, 0x035AC4),
            FileHashRegion(0x6732A0, 0x03607C),
            FileHashRegion(0x6A9428, 0x035AC4),
            FileHashRegion(0x6DEEF0, 0x03607C),
            FileHashRegion(0x715078, 0x035AC4),
            FileHashRegion(0x74AB40, 0x03607C),
            FileHashRegion(0x780CC8, 0x035AC4),
            FileHashRegion(0x7B6790, 0x03607C),
            FileHashRegion(0x7EC918, 0x035AC4),
            FileHashRegion(0x8223E0, 0x03607C),
            FileHashRegion(0x858460, 0x2684D4),
        ]),

        // 2.0.x — main.dat = 0x8F1BB0
        0x8F1BB0: FileHashDetails(fileName: mainFile, fileSize: 0x8F1BB0, regions: [
            FileHashRegion(0x000110, 0x1e339c),
            FileHashRegion(0x1e34b0, 0x36406c),
            FileHashRegion(0x547630, 0x03693c),
            FileHashRegion(0x57df70, 0x033acc),
            FileHashRegion(0x5b1b50, 0x03693c),
            FileHashRegion(0x5e8490, 0x033acc),
            FileHashRegion(0x61c070, 0x03693c),
            FileHashRegion(0x6529b0, 0x033acc),
            FileHashRegion(0x686590, 0x03693c),
            FileHashRegion(0x6bced0, 0x033acc),
            FileHashRegion(0x6f0ab0, 0x03693c),
            FileHashRegion(0x7273f0, 0x033acc),
            FileHashRegion(0x75afd0, 0x03693c),
            FileHashRegion(0x791910, 0x033acc),
            FileHashRegion(0x7c54f0, 0x03693c),
            FileHashRegion(0x7fbe30, 0x033acc),
            FileHashRegion(0x82fa10, 0x03693c),
            FileHashRegion(0x866350, 0x033acc),
            FileHashRegion(0x899e20, 0x057d8c),
        ]),

        // 3.0.x — main.dat = 0x9B0E90
        0x9B0E90: FileHashDetails(fileName: mainFile, fileSize: 0x9B0E90, regions: [
            FileHashRegion(0x000110, 0x1e339c),
            FileHashRegion(0x1e34b0, 0x3d089c),
            FileHashRegion(0x5b3e60, 0x037acc),
            FileHashRegion(0x5eb930, 0x03ce5c),
            FileHashRegion(0x6288a0, 0x037acc),
            FileHashRegion(0x660370, 0x03ce5c),
            FileHashRegion(0x69d2e0, 0x037acc),
            FileHashRegion(0x6d4db0, 0x03ce5c),
            FileHashRegion(0x711d20, 0x037acc),
            FileHashRegion(0x7497f0, 0x03ce5c),
            FileHashRegion(0x786760, 0x037acc),
            FileHashRegion(0x7be230, 0x03ce5c),
            FileHashRegion(0x7fb1a0, 0x037acc),
            FileHashRegion(0x832c70, 0x03ce5c),
            FileHashRegion(0x86fbe0, 0x037acc),
            FileHashRegion(0x8a76b0, 0x03ce5c),
            FileHashRegion(0x8e4620, 0x037acc),
            FileHashRegion(0x91c0f0, 0x03ce5c),
            FileHashRegion(0x958f50, 0x057f3c),
        ]),
    ]

    // MARK: - personal.dat tables

    private static let personalTable: [UInt32: FileHashDetails] = [
        // 2.0.x — 0x6A520
        0x6A520: FileHashDetails(fileName: personalFile, fileSize: 0x6A520, regions: [
            FileHashRegion(0x00110, 0x3693c),
            FileHashRegion(0x36a50, 0x33acc),
        ]),
        // 3.0.x — 0x74A40
        0x74A40: FileHashDetails(fileName: personalFile, fileSize: 0x74A40, regions: [
            FileHashRegion(0x00110, 0x37acc),
            FileHashRegion(0x37be0, 0x3ce5c),
        ]),
    ]

    // MARK: - postbox.dat tables (single region from 1.7+)

    private static let postboxTable: [UInt32: FileHashDetails] = [
        // 1.0.0 .. 1.6.0 share 0xB44580 / 0xB44590 layouts
        0xB44580: FileHashDetails(fileName: postboxFile, fileSize: 0xB44580, regions: [
            FileHashRegion(0x000100, 0xB4447C),
        ]),
        0xB44590: FileHashDetails(fileName: postboxFile, fileSize: 0xB44590, regions: [
            FileHashRegion(0x000100, 0xB4447C),
        ]),
        // 1.7.0+ — reduced size 0x47430, single region.
        0x47430: FileHashDetails(fileName: postboxFile, fileSize: 0x47430, regions: [
            FileHashRegion(0x100, 0x4732c),
        ]),
    ]

    // MARK: - photo_studio_island.dat tables

    private static let photoTable: [UInt32: FileHashDetails] = [
        // 1.0.0
        0x263B4: FileHashDetails(fileName: photoFile, fileSize: 0x263B4, regions: [
            FileHashRegion(0x100, 0x262B0),
        ]),
        // 1.1.x
        0x263C0: FileHashDetails(fileName: photoFile, fileSize: 0x263C0, regions: [
            FileHashRegion(0x100, 0x262BC),
        ]),
        // 1.2.x .. 1.9.x
        0x2C9C0: FileHashDetails(fileName: photoFile, fileSize: 0x2C9C0, regions: [
            FileHashRegion(0x100, 0x2C8BC),
        ]),
        // 1.10.x .. 1.11.x
        0x2C9D0: FileHashDetails(fileName: photoFile, fileSize: 0x2C9D0, regions: [
            FileHashRegion(0x100, 0x2C8CC),
        ]),
        // 2.0.x .. 3.0.x
        0x2F650: FileHashDetails(fileName: photoFile, fileSize: 0x2F650, regions: [
            FileHashRegion(0x100, 0x2f54c),
        ]),
    ]

    // MARK: - profile.dat tables

    private static let profileTable: [UInt32: FileHashDetails] = [
        // 1.0.0
        0x69508: FileHashDetails(fileName: profileFile, fileSize: 0x69508, regions: [
            FileHashRegion(0x100, 0x69404),
        ]),
        // 1.1.0+ (stable through 3.0.x): 0x69560
        0x69560: FileHashDetails(fileName: profileFile, fileSize: 0x69560, regions: [
            FileHashRegion(0x100, 0x6945c),
        ]),
    ]

    // MARK: - wherearen.dat tables (introduced in 2.0.0)

    private static let whereArenTable: [UInt32: FileHashDetails] = [
        0xB8A4E0: FileHashDetails(fileName: whereArenFile, fileSize: 0xB8A4E0, regions: [
            FileHashRegion(0x100, 0xB8A3DC),
        ]),
    ]
}
