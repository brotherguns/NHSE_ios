//
//  Murmur3.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Hashing/Murmur3.cs.
//  Hashes input as a stream of little-endian uint32s. Length must be a multiple of 4.
//

import Foundation

public enum Murmur3 {

    @inline(__always)
    private static func scramble(_ value: UInt32) -> UInt32 {
        // Matches the original (somewhat unusual) NHSE scramble step.
        var v = (value &* 0x16A88000) | ((value &* 0xCC9E2D51) &>> 17)
        v &*= 0x1B873593
        return v
    }

    @inline(__always)
    private static func advance(_ checksum: UInt32, _ value: UInt32) -> UInt32 {
        var c = checksum ^ scramble(value)
        c = (c &>> 19) | (c &<< 13)
        c = (c &* 5) &+ 0xE6546B64
        return c
    }

    @inline(__always)
    private static func finalize(_ checksum: UInt32, _ length: UInt32) -> UInt32 {
        var c = checksum ^ length
        c ^= c &>> 16
        c &*= 0x85EBCA6B
        c ^= c &>> 13
        c &*= 0xC2B2AE35
        c ^= c &>> 16
        return c
    }

    /// Compute the Murmur3 hash over `data`. `data.count % 4` must be 0.
    public static func hash(_ data: Data, seed: UInt32 = 0) -> UInt32 {
        precondition(data.count % 4 == 0, "Murmur3.hash: length must be a multiple of 4")
        var checksum = seed
        let words = data.count / 4
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.bindMemory(to: UInt8.self)
            for i in 0..<words {
                let off = i * 4
                let v = UInt32(base[off])
                    | (UInt32(base[off + 1]) << 8)
                    | (UInt32(base[off + 2]) << 16)
                    | (UInt32(base[off + 3]) << 24)
                checksum = advance(checksum, v)
            }
        }
        return finalize(checksum, UInt32(data.count))
    }
}
