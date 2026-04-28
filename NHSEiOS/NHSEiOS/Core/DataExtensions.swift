//
//  DataExtensions.swift
//  NHSEiOS
//
//  Little-endian binary readers/writers operating on Data.
//  All offsets are zero-relative to the Data slice's logical start.
//

import Foundation

extension Data {

    @inlinable
    func readU8(at offset: Int) -> UInt8 {
        precondition(offset + 1 <= count, "readU8 out-of-bounds")
        return self.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> UInt8 in
            raw.bindMemory(to: UInt8.self)[offset]
        }
    }

    @inlinable
    func readU16LE(at offset: Int) -> UInt16 {
        precondition(offset + 2 <= count, "readU16LE out-of-bounds")
        return self.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> UInt16 in
            let b = raw.bindMemory(to: UInt8.self)
            return UInt16(b[offset]) | (UInt16(b[offset + 1]) << 8)
        }
    }

    @inlinable
    func readU32LE(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count, "readU32LE out-of-bounds")
        return self.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> UInt32 in
            let b = raw.bindMemory(to: UInt8.self)
            return UInt32(b[offset])
                | (UInt32(b[offset + 1]) << 8)
                | (UInt32(b[offset + 2]) << 16)
                | (UInt32(b[offset + 3]) << 24)
        }
    }

    @inlinable
    func readU64LE(at offset: Int) -> UInt64 {
        precondition(offset + 8 <= count, "readU64LE out-of-bounds")
        return self.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> UInt64 in
            let b = raw.bindMemory(to: UInt8.self)
            var v: UInt64 = 0
            for i in 0..<8 {
                v |= UInt64(b[offset + i]) << (8 * i)
            }
            return v
        }
    }

    mutating func writeU8(_ value: UInt8, at offset: Int) {
        precondition(offset + 1 <= count, "writeU8 out-of-bounds")
        self[self.startIndex + offset] = value
    }

    mutating func writeU16LE(_ value: UInt16, at offset: Int) {
        precondition(offset + 2 <= count, "writeU16LE out-of-bounds")
        self[self.startIndex + offset]     = UInt8(value & 0xFF)
        self[self.startIndex + offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    mutating func writeU32LE(_ value: UInt32, at offset: Int) {
        precondition(offset + 4 <= count, "writeU32LE out-of-bounds")
        for i in 0..<4 {
            self[self.startIndex + offset + i] = UInt8((value >> (8 * i)) & 0xFF)
        }
    }

    mutating func writeU64LE(_ value: UInt64, at offset: Int) {
        precondition(offset + 8 <= count, "writeU64LE out-of-bounds")
        for i in 0..<8 {
            self[self.startIndex + offset + i] = UInt8((value >> (8 * i)) & 0xFF)
        }
    }

    /// Read a fixed-width slice as a contiguous Data. Offsets are zero-relative.
    func slice(at offset: Int, length: Int) -> Data {
        precondition(offset + length <= count, "slice out-of-bounds")
        let start = self.startIndex + offset
        return self.subdata(in: start..<(start + length))
    }

    /// Replace `length` bytes at `offset` with the contents of `bytes`. `bytes.count` must equal `length`.
    mutating func replaceRange(at offset: Int, length: Int, with bytes: Data) {
        precondition(bytes.count == length, "replaceRange size mismatch")
        precondition(offset + length <= count, "replaceRange out-of-bounds")
        let start = self.startIndex + offset
        self.replaceSubrange(start..<(start + length), with: bytes)
    }

    /// Find every occurrence of `needle` in this Data and replace with `replacement`.
    /// `needle.count` must equal `replacement.count` (size-preserving).
    mutating func replaceAllOccurrences(of needle: Data, with replacement: Data) {
        precondition(needle.count == replacement.count, "replaceAllOccurrences size mismatch")
        guard !needle.isEmpty, count >= needle.count else { return }
        let n = needle.count
        var i = 0
        while i + n <= count {
            // Compare bytewise.
            var match = true
            for k in 0..<n {
                if self[self.startIndex + i + k] != needle[needle.startIndex + k] {
                    match = false
                    break
                }
            }
            if match {
                self.replaceRange(at: i, length: n, with: replacement)
                i += n
            } else {
                i += 1
            }
        }
    }
}

// MARK: - Bit ops on UInt32

@inlinable
func rotateRight32(_ value: UInt32, _ amount: Int) -> UInt32 {
    let a = amount & 31
    if a == 0 { return value }
    return (value &>> a) | (value &<< (32 - a))
}

@inlinable
func rotateLeft32(_ value: UInt32, _ amount: Int) -> UInt32 {
    let a = amount & 31
    if a == 0 { return value }
    return (value &<< a) | (value &>> (32 - a))
}
