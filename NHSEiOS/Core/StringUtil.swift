//
//  StringUtil.swift
//  NHSEiOS
//
//  NH save files store strings as UTF-16 LE, null-padded to a fixed character count.
//  `maxCharCount` = number of UTF-16 code units (NOT bytes); each char is 2 bytes.
//

import Foundation

public enum StringUtil {

    /// Read up to `maxCharCount` UTF-16 LE code units from `data` at `offset`,
    /// stopping at the first NUL (0x0000) terminator.
    public static func getString(from data: Data, at offset: Int, maxCharCount: Int) -> String {
        let byteLen = maxCharCount * 2
        guard offset + byteLen <= data.count else { return "" }

        var chars = [UInt16]()
        chars.reserveCapacity(maxCharCount)
        for i in 0..<maxCharCount {
            let cu = data.readU16LE(at: offset + (i * 2))
            if cu == 0 { break }
            chars.append(cu)
        }
        return String(decoding: chars, as: UTF16.self)
    }

    /// Encode a Swift string into a fixed-size little-endian UTF-16 buffer of length
    /// `maxCharCount * 2` bytes, NUL-padded after the last character.
    public static func getBytes(_ value: String, maxCharCount: Int) -> Data {
        let byteLen = maxCharCount * 2
        var out = Data(count: byteLen)

        var written = 0
        for scalar in value.unicodeScalars {
            // Stop if we don't have room for one more BMP char + NUL terminator.
            if written + 1 >= maxCharCount { break }

            // Emit as UTF-16. Most characters are BMP; surrogates need 2 code units.
            for cu in String(scalar).utf16 {
                if written >= maxCharCount { break }
                out.writeU16LE(cu, at: written * 2)
                written += 1
            }
        }
        // Remaining bytes already 0 (NUL pad).
        return out
    }
}
