//
//  XorShift128.swift
//  NHSEiOS
//
//  Port of NHSE.Core/Util/XorShift128.cs (xor128 RNG, Mersenne-style init).
//

import Foundation

public struct XorShift128 {
    private var a: UInt32
    private var b: UInt32
    private var c: UInt32
    private var d: UInt32

    private static let mersenne: UInt32 = 0x6C078965

    public init(seed: UInt32) {
        let m = XorShift128.mersenne
        a = (m &* (seed ^ (seed >> 30))) &+ 1
        b = (m &* (a    ^ (a    >> 30))) &+ 2
        c = (m &* (b    ^ (b    >> 30))) &+ 3
        d = (m &* (c    ^ (c    >> 30))) &+ 4
    }

    @inlinable
    public mutating func next() -> UInt32 {
        var t = a
        a = b
        b = c
        c = d                       // c now holds the OLD d
        t ^= t &<< 11
        t ^= t &>> 8
        d = t ^ d ^ (d &>> 19)      // RHS d is still the OLD d
        return d
    }

    @inlinable
    public mutating func next64() -> UInt64 {
        let hi = UInt64(next()) << 32
        let lo = UInt64(next())
        return hi | lo
    }
}
