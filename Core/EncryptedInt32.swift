//
//  EncryptedInt32.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Encryption/EncryptedInt32.cs.
//  Used for wallet, bank, Nook Miles. 8 bytes on disk:
//    [0..4) = encrypted u32
//    [4..6) = adjust (u16 LE)
//    [6]    = shift (u8)
//    [7]    = checksum byte (over all 4 encrypted bytes)
//

import Foundation

public struct EncryptedInt32: Equatable {
    private static let encryptionConstant: UInt32 = 0x80E32B11
    private static let shiftBase: UInt8 = 3

    public var value: UInt32
    public var adjust: UInt16
    public var shift: UInt8

    public init(value: UInt32, adjust: UInt16 = 0, shift: UInt8 = 0) {
        self.value = value
        self.adjust = adjust
        self.shift = shift
    }

    /// Decrypt the 32-bit integer encoded at `offset` of `data`, with checksum verification.
    public static func read(from data: Data, at offset: Int) -> EncryptedInt32? {
        guard offset + 8 <= data.count else { return nil }
        let encrypted = data.readU32LE(at: offset)
        let adjust    = data.readU16LE(at: offset + 4)
        let shift     = data.readU8(at: offset + 6)
        let checksum  = data.readU8(at: offset + 7)

        guard checksum == calculateChecksum(encrypted) else { return nil }

        let decrypted = decrypt(encrypted: encrypted, shift: shift, adjust: adjust)
        return EncryptedInt32(value: decrypted, adjust: adjust, shift: shift)
    }

    /// Re-encrypt and write back to `data` at `offset`.
    public func write(to data: inout Data, at offset: Int) {
        let encrypted = EncryptedInt32.encrypt(value: value, shift: shift, adjust: adjust)
        data.writeU32LE(encrypted, at: offset)
        data.writeU16LE(adjust,    at: offset + 4)
        data.writeU8(shift,        at: offset + 6)
        data.writeU8(EncryptedInt32.calculateChecksum(encrypted), at: offset + 7)
    }

    public static func calculateChecksum(_ value: UInt32) -> UInt8 {
        // Sum of the four bytes of the encrypted u32, minus 0x2D (truncated to a byte).
        let byteSum = value &+ (value &>> 16) &+ (value &>> 24) &+ (value &>> 8)
        return UInt8((byteSum &- 0x2D) & 0xFF)
    }

    public static func decrypt(encrypted: UInt32, shift: UInt8, adjust: UInt16) -> UInt32 {
        let rotated = rotateRight32(encrypted, Int(shift &+ shiftBase))
        return rotated &+ encryptionConstant &- UInt32(adjust)
    }

    public static func encrypt(value: UInt32, shift: UInt8, adjust: UInt16) -> UInt32 {
        let adjusted = value &+ UInt32(adjust) &- encryptionConstant
        return rotateLeft32(adjusted, Int(shift &+ shiftBase))
    }
}
