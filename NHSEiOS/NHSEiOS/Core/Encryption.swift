//
//  Encryption.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Encryption/Encryption.cs.
//  Decrypts and encrypts the (data,header) pair that backs every save file.
//

import Foundation

public enum EncryptionError: Error, CustomStringConvertible {
    case headerTooSmall(actual: Int, required: Int)
    case dataNotBlockAligned(length: Int)
    case versionDataTooSmall(actual: Int, required: Int)
    case aes(underlying: Error)

    public var description: String {
        switch self {
        case .headerTooSmall(let a, let r):
            return "Header too small (\(a) < \(r))"
        case .dataNotBlockAligned(let n):
            return "Data length \(n) is not a multiple of 16"
        case .versionDataTooSmall(let a, let r):
            return "Version data too small (\(a) < \(r))"
        case .aes(let e):
            return "AES error: \(e)"
        }
    }
}

public enum Encryption {

    private static let blockSize = AesCtr.blockSize

    // MARK: - Public API

    /// Decrypt `encData` in place using key/counter material derived from `headerData`.
    /// `headerData` must be at least 0x300 bytes; only `headerData[0x100..<0x300]` is consumed.
    public static func decrypt(headerData: Data, encData: inout [UInt8]) throws {
        guard headerData.count >= 0x300 else {
            throw EncryptionError.headerTooSmall(actual: headerData.count, required: 0x300)
        }
        guard encData.count % blockSize == 0 else {
            throw EncryptionError.dataNotBlockAligned(length: encData.count)
        }

        let words = readImportantWords(from: headerData, at: 0x100)

        var key     = getParam(data: words, index: 0, byteCount: blockSize)
        var counter = getParam(data: words, index: 2, byteCount: blockSize)

        do {
            try AesCtr.crypt(data: &encData, key: key, counter: &counter)
        } catch {
            throw EncryptionError.aes(underlying: error)
        }

        scrub(&key)
        scrub(&counter)
    }

    /// Encrypt `data` (plaintext) using the given `seed` and 0x100 bytes of `versionData`
    /// (= the original header's first 0x100 bytes — we preserve it verbatim).
    /// Returns (encryptedData, freshHeader).
    public static func encrypt(data: [UInt8], seed: UInt32, versionData: Data) throws -> (data: [UInt8], header: Data) {
        guard versionData.count >= 0x100 else {
            throw EncryptionError.versionDataTooSmall(actual: versionData.count, required: 0x100)
        }
        guard data.count % blockSize == 0 else {
            throw EncryptionError.dataNotBlockAligned(length: data.count)
        }

        // Generate 128 random uints from `seed`. These become the new header's important region.
        var rng = XorShift128(seed: seed)
        var encryptData = [UInt32](repeating: 0, count: 128)
        for i in 0..<encryptData.count {
            encryptData[i] = rng.next()
        }

        // Build the new header file: [versionData[0..0x100]] + [encryptData as 0x200 bytes of LE uint32s].
        var headerOut = Data(count: 0x300)
        // First 0x100 bytes verbatim from versionData.
        headerOut.replaceRange(at: 0, length: 0x100, with: versionData.slice(at: 0, length: 0x100))
        // Next 0x200 bytes: encryptData as little-endian uint32s.
        for i in 0..<encryptData.count {
            headerOut.writeU32LE(encryptData[i], at: 0x100 + (i * 4))
        }

        // Derive key + counter from the freshly generated words.
        var key     = getParam(data: encryptData, index: 0, byteCount: blockSize)
        var counter = getParam(data: encryptData, index: 2, byteCount: blockSize)

        // Encrypt a copy of the plaintext.
        var encrypted = data
        do {
            try AesCtr.crypt(data: &encrypted, key: key, counter: &counter)
        } catch {
            throw EncryptionError.aes(underlying: error)
        }

        scrub(&key)
        scrub(&counter)

        return (encrypted, headerOut)
    }

    // MARK: - Internals

    /// Read 128 little-endian uint32 words from `data` starting at `at`.
    private static func readImportantWords(from data: Data, at offset: Int) -> [UInt32] {
        var u32 = [UInt32](repeating: 0, count: 0x200 / 4)
        for k in 0..<u32.count {
            u32[k] = data.readU32LE(at: offset + (k * 4))
        }
        return u32
    }

    /// The two-word index scheme used by NHSE to derive key/counter material.
    private static func getParam(data: [UInt32], index: Int, byteCount: Int) -> [UInt8] {
        let seedIdx = Int(data[index]     & 0x7F)
        var rng     = XorShift128(seed: data[seedIdx])
        let prmsIdx = Int(data[index + 1] & 0x7F)
        let prms    = Int(data[prmsIdx]   & 0x7F)
        let rolls   = (prms & 0xF) + 1

        for _ in 0..<rolls { _ = rng.next64() }

        var out = [UInt8](repeating: 0, count: byteCount)
        for j in 0..<byteCount {
            out[j] = UInt8((rng.next() >> 24) & 0xFF)
        }
        return out
    }

    private static func scrub(_ buf: inout [UInt8]) {
        for i in 0..<buf.count { buf[i] = 0 }
    }
}
