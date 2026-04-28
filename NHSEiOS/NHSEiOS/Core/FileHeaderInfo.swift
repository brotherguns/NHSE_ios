//
//  FileHeaderInfo.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Save/Meta/FileHeaderInfo.cs and the revision detection
//  logic from RevisionChecker.cs.
//

import Foundation

public struct FileHeaderInfo: Equatable, Hashable, CustomStringConvertible {
    public static let size: Int = 0x40

    public let major: UInt32          // 0x00
    public let minor: UInt32          // 0x04
    public let unk1: UInt16           // 0x08
    public let headerRevision: UInt16 // 0x0A
    public let unk2: UInt16           // 0x0C
    public let saveRevision: UInt16   // 0x0E
    // 0x10..0x40 reserved/padding.

    public init(major: UInt32, minor: UInt32,
                unk1: UInt16, headerRevision: UInt16,
                unk2: UInt16, saveRevision: UInt16)
    {
        self.major = major
        self.minor = minor
        self.unk1 = unk1
        self.headerRevision = headerRevision
        self.unk2 = unk2
        self.saveRevision = saveRevision
    }

    /// Parse the first 0x40 bytes of decrypted plaintext.
    public init?(decrypted: Data) {
        guard decrypted.count >= FileHeaderInfo.size else { return nil }
        self.major          = decrypted.readU32LE(at: 0x00)
        self.minor          = decrypted.readU32LE(at: 0x04)
        self.unk1           = decrypted.readU16LE(at: 0x08)
        self.headerRevision = decrypted.readU16LE(at: 0x0A)
        self.unk2           = decrypted.readU16LE(at: 0x0C)
        self.saveRevision   = decrypted.readU16LE(at: 0x0E)
    }

    public var description: String {
        String(format: "Major=0x%X Minor=0x%X HdrRev=%u SaveRev=%u Unk1=%u Unk2=%u",
               major, minor, headerRevision, saveRevision, unk1, unk2)
    }
}

public enum SaveRevision: Int, CaseIterable {
    case v1_0_0 = 0
    case v1_1_0, v1_1_1, v1_1_2, v1_1_3, v1_1_4
    case v1_2_0, v1_2_1
    case v1_3_0, v1_3_1
    case v1_4_0, v1_4_1, v1_4_2
    case v1_5_0, v1_5_1
    case v1_6_0
    case v1_7_0
    case v1_8_0
    case v1_9_0
    case v1_10_0
    case v1_11_0, v1_11_1
    case v2_0_0, v2_0_1, v2_0_2, v2_0_3, v2_0_4, v2_0_5, v2_0_6, v2_0_7, v2_0_8
    case v3_0_0, v3_0_1, v3_0_2

    public var displayName: String {
        switch self {
        case .v1_0_0:  return "1.0.0"
        case .v1_1_0:  return "1.1.0"
        case .v1_1_1:  return "1.1.1"
        case .v1_1_2:  return "1.1.2"
        case .v1_1_3:  return "1.1.3"
        case .v1_1_4:  return "1.1.4"
        case .v1_2_0:  return "1.2.0"
        case .v1_2_1:  return "1.2.1"
        case .v1_3_0:  return "1.3.0"
        case .v1_3_1:  return "1.3.1"
        case .v1_4_0:  return "1.4.0"
        case .v1_4_1:  return "1.4.1"
        case .v1_4_2:  return "1.4.2"
        case .v1_5_0:  return "1.5.0"
        case .v1_5_1:  return "1.5.1"
        case .v1_6_0:  return "1.6.0"
        case .v1_7_0:  return "1.7.0"
        case .v1_8_0:  return "1.8.0"
        case .v1_9_0:  return "1.9.0"
        case .v1_10_0: return "1.10.0"
        case .v1_11_0: return "1.11.0"
        case .v1_11_1: return "1.11.1"
        case .v2_0_0:  return "2.0.0"
        case .v2_0_1:  return "2.0.1"
        case .v2_0_2:  return "2.0.2"
        case .v2_0_3:  return "2.0.3"
        case .v2_0_4:  return "2.0.4"
        case .v2_0_5:  return "2.0.5"
        case .v2_0_6:  return "2.0.6"
        case .v2_0_7:  return "2.0.7"
        case .v2_0_8:  return "2.0.8"
        case .v3_0_0:  return "3.0.0"
        case .v3_0_1:  return "3.0.1"
        case .v3_0_2:  return "3.0.2"
        }
    }

    /// Editing is supported in this app for revisions 2.0.0+. Older saves load
    /// read-only (we don't ship offset tables for them). Adjust as you fill in
    /// older offsets.
    public var isEditingSupported: Bool {
        return rawValue >= SaveRevision.v2_0_0.rawValue
    }
}

public enum RevisionTable {

    public static let headers: [FileHeaderInfo] = [
        // 1.0.0
        .init(major: 0x00067, minor: 0x0006F, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 0),
        // 1.1.0..1.1.4
        .init(major: 0x0006D, minor: 0x00078, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 1),
        .init(major: 0x0006D, minor: 0x00078, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 2),
        .init(major: 0x0006D, minor: 0x00078, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 3),
        .init(major: 0x0006D, minor: 0x00078, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 4),
        .init(major: 0x0006D, minor: 0x00078, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 5),
        // 1.2.x
        .init(major: 0x20006, minor: 0x20008, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 6),
        .init(major: 0x20006, minor: 0x20008, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 7),
        // 1.3.x
        .init(major: 0x40002, minor: 0x40008, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 8),
        .init(major: 0x40002, minor: 0x40008, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 9),
        // 1.4.x
        .init(major: 0x50001, minor: 0x5000B, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 10),
        .init(major: 0x50001, minor: 0x5000B, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 11),
        .init(major: 0x50001, minor: 0x5000B, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 12),
        // 1.5.x
        .init(major: 0x60001, minor: 0x6000C, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 13),
        .init(major: 0x60001, minor: 0x6000C, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 14),
        // 1.6.0
        .init(major: 0x70001, minor: 0x70006, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 15),
        // 1.7.0
        .init(major: 0x74001, minor: 0x74005, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 16),
        // 1.8.0
        .init(major: 0x78001, minor: 0x78001, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 17),
        // 1.9.0
        .init(major: 0x7C001, minor: 0x7C006, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 18),
        // 1.10.0
        .init(major: 0x7D001, minor: 0x7D004, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 19),
        // 1.11.0..1.11.1
        .init(major: 0x7E001, minor: 0x7E001, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 20),
        .init(major: 0x7E001, minor: 0x7E001, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 21),
        // 2.0.0..2.0.8
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 22),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 23),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 24),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 25),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 26),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 27),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 28),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 29),
        .init(major: 0x80009, minor: 0x80085, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 30),
        // 3.0.0..3.0.2
        .init(major: 0xA0002, minor: 0xA0028, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 31),
        .init(major: 0xA0002, minor: 0xA0028, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 32),
        .init(major: 0xA0002, minor: 0xA0028, unk1: 2, headerRevision: 0, unk2: 2, saveRevision: 33),
    ]

    /// Per-revision expected *decrypted* main.dat byte length.
    public static let mainDatSizes: [UInt32] = [
        0xAC0938,
        0xAC2AA0, 0xAC2AA0, 0xAC2AA0, 0xAC2AA0, 0xAC2AA0,
        0xACECD0, 0xACECD0,
        0xACED80, 0xACED80,
        0xB05790, 0xB05790, 0xB05790,
        0xB20750, 0xB20750,
        0xB258E0,
        0x849C30,
        0x849C30,
        0x86D560,
        0x86D570,
        0x86D570, 0x86D570,
        0x8F1BB0, 0x8F1BB0, 0x8F1BB0, 0x8F1BB0, 0x8F1BB0,
        0x8F1BB0, 0x8F1BB0, 0x8F1BB0, 0x8F1BB0,
        0x9B0E90, 0x9B0E90, 0x9B0E90,
    ]

    public static func index(of header: FileHeaderInfo) -> Int {
        return headers.firstIndex(of: header) ?? -1
    }
}
