//
//  AesCtr.swift
//  NHSEiOS
//
//  AES-128 in CTR mode with a big-endian counter, matching NHSE.
//  AES-CTR is symmetric — encrypt and decrypt are the same operation.
//

import Foundation
import CommonCrypto

public enum AesCtrError: Error, CustomStringConvertible {
    case ccCryptFailed(CCCryptorStatus)
    case wrongBlockSize

    public var description: String {
        switch self {
        case .ccCryptFailed(let s): return "CommonCrypto AES failed (status=\(s))"
        case .wrongBlockSize:       return "AES key/counter must be 16 bytes"
        }
    }
}

public enum AesCtr {

    public static let blockSize: Int = 16

    /// Transform `data` in place using AES-128-CTR.
    public static func crypt(data: inout [UInt8], key: [UInt8], counter: inout [UInt8]) throws {
        guard key.count == 16, counter.count == 16 else { throw AesCtrError.wrongBlockSize }

        var keystream = [UInt8](repeating: 0, count: blockSize)

        var offset = 0
        let total = data.count
        while offset < total {
            try aesEncryptBlockECB(input: counter, key: key, output: &keystream)
            let blockLen = Swift.min(blockSize, total - offset)
            for j in 0..<blockLen {
                data[offset + j] ^= keystream[j]
            }
            incrementBigEndian(&counter)
            offset += blockSize
        }
    }

    /// One-shot AES-128-ECB on a single 16-byte block (no padding).
    private static func aesEncryptBlockECB(input: [UInt8], key: [UInt8], output: inout [UInt8]) throws {
        var bytesOut = 0
        let status: CCCryptorStatus = input.withUnsafeBufferPointer { inBuf in
            key.withUnsafeBufferPointer { keyBuf in
                output.withUnsafeMutableBufferPointer { outBuf in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyBuf.baseAddress, kCCKeySizeAES128,
                        nil,
                        inBuf.baseAddress, blockSize,
                        outBuf.baseAddress, blockSize,
                        &bytesOut
                    )
                }
            }
        }
        guard status == kCCSuccess, bytesOut == blockSize else {
            throw AesCtrError.ccCryptFailed(status)
        }
    }

    /// Treat last byte as least-significant; carry propagates leftward.
    private static func incrementBigEndian(_ counter: inout [UInt8]) {
        var i = counter.count - 1
        while i >= 0 {
            counter[i] = counter[i] &+ 1
            if counter[i] != 0 { return }
            i -= 1
        }
    }
}
