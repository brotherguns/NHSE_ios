//
//  ZipArchive.swift
//  NHSEiOS
//
//  Minimal pure-Swift ZIP reader / writer supporting STORE (method 0) and
//  DEFLATE (method 8) — enough to round-trip a save folder zip on iOS without
//  any external dependencies. Uses Apple's Compression framework for deflate.
//
//  Limitations:
//   - No ZIP64. Files & archives must be < 4 GiB. (Save folders are far smaller.)
//   - No encryption / no multi-volume.
//   - Stores file names as UTF-8 (sets the language-encoding flag bit).
//

import Foundation
import Compression

public enum ZipError: Error, CustomStringConvertible {
    case malformed(String)
    case unsupportedMethod(UInt16)
    case crcMismatch(name: String)
    case compressFailed
    case decompressFailed

    public var description: String {
        switch self {
        case .malformed(let s):           return "Malformed zip: \(s)"
        case .unsupportedMethod(let m):   return "Unsupported zip compression method: \(m)"
        case .crcMismatch(let n):         return "CRC mismatch on entry: \(n)"
        case .compressFailed:             return "Deflate failed"
        case .decompressFailed:           return "Inflate failed"
        }
    }
}

public struct ZipEntry {
    public var name: String           // forward-slash separated relative path
    public var data: Data             // uncompressed contents
    public var modificationDate: Date

    public init(name: String, data: Data, modificationDate: Date = Date()) {
        self.name = name.replacingOccurrences(of: "\\", with: "/")
        self.data = data
        self.modificationDate = modificationDate
    }

    public var isDirectory: Bool { name.hasSuffix("/") }
}

public final class ZipArchive {

    public var entries: [ZipEntry] = []

    public init() {}

    public init(entries: [ZipEntry]) {
        self.entries = entries
    }

    public func addEntry(_ entry: ZipEntry) {
        entries.append(entry)
    }

    /// Look up the first entry with this exact name (case sensitive).
    public func entry(named name: String) -> ZipEntry? {
        let n = name.replacingOccurrences(of: "\\", with: "/")
        return entries.first { $0.name == n }
    }

    // MARK: - Reading

    public static func read(from data: Data) throws -> ZipArchive {
        // Locate End-of-Central-Directory record by scanning backward.
        guard let eocdOffset = findEOCD(in: data) else {
            throw ZipError.malformed("EOCD signature not found")
        }
        let eocd = data.subdata(in: eocdOffset..<min(eocdOffset + 22, data.count))
        guard eocd.count >= 22 else { throw ZipError.malformed("EOCD truncated") }

        let cdEntryCount = Int(eocd.readU16LE(at: 10))
        let cdSize       = Int(eocd.readU32LE(at: 12))
        let cdOffset     = Int(eocd.readU32LE(at: 16))

        guard cdOffset + cdSize <= data.count else {
            throw ZipError.malformed("Central directory out-of-bounds")
        }

        let archive = ZipArchive()
        var p = cdOffset
        for _ in 0..<cdEntryCount {
            guard p + 46 <= data.count else { throw ZipError.malformed("CDH truncated") }
            let sig = data.readU32LE(at: p)
            guard sig == 0x02014b50 else { throw ZipError.malformed("Bad CDH signature") }

            let method   = data.readU16LE(at: p + 10)
            let dosTime  = data.readU16LE(at: p + 12)
            let dosDate  = data.readU16LE(at: p + 14)
            let crcExp   = data.readU32LE(at: p + 16)
            let compSize = Int(data.readU32LE(at: p + 20))
            let uncSize  = Int(data.readU32LE(at: p + 24))
            let nameLen  = Int(data.readU16LE(at: p + 28))
            let extraLen = Int(data.readU16LE(at: p + 30))
            let cmtLen   = Int(data.readU16LE(at: p + 32))
            let lhOffset = Int(data.readU32LE(at: p + 42))

            guard p + 46 + nameLen <= data.count else { throw ZipError.malformed("CDH name truncated") }
            let nameData = data.subdata(in: (p + 46)..<(p + 46 + nameLen))
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Walk to the local file header and skip past its variable-length fields.
            guard lhOffset + 30 <= data.count else { throw ZipError.malformed("LFH out-of-bounds") }
            let lfhSig = data.readU32LE(at: lhOffset)
            guard lfhSig == 0x04034b50 else { throw ZipError.malformed("Bad LFH signature for \(name)") }
            let lfhNameLen  = Int(data.readU16LE(at: lhOffset + 26))
            let lfhExtraLen = Int(data.readU16LE(at: lhOffset + 28))
            let dataStart   = lhOffset + 30 + lfhNameLen + lfhExtraLen
            guard dataStart + compSize <= data.count else {
                throw ZipError.malformed("Entry data out-of-bounds for \(name)")
            }
            let raw = data.subdata(in: dataStart..<(dataStart + compSize))

            let uncompressed: Data
            switch method {
            case 0:
                uncompressed = raw
            case 8:
                uncompressed = try inflate(raw, expectedSize: uncSize)
            default:
                throw ZipError.unsupportedMethod(method)
            }

            // Verify CRC unless this is a directory entry (size 0).
            if uncSize > 0 {
                let crcGot = crc32(uncompressed)
                if crcGot != crcExp {
                    throw ZipError.crcMismatch(name: name)
                }
            }

            archive.entries.append(ZipEntry(
                name: name,
                data: uncompressed,
                modificationDate: dosDateTimeToDate(dosDate: dosDate, dosTime: dosTime)
            ))

            p += 46 + nameLen + extraLen + cmtLen
        }
        return archive
    }

    private static func findEOCD(in data: Data) -> Int? {
        let sig: [UInt8] = [0x50, 0x4B, 0x05, 0x06]
        let n = data.count
        if n < 22 { return nil }
        let scanStart = max(0, n - (22 + 0xFFFF)) // EOCD comment max 65535
        var i = n - 22
        while i >= scanStart {
            if data[i] == sig[0] && data[i+1] == sig[1] && data[i+2] == sig[2] && data[i+3] == sig[3] {
                return i
            }
            i -= 1
        }
        return nil
    }

    // MARK: - Writing

    /// Build a ZIP archive in memory. Each non-empty entry is DEFLATEd if it
    /// shrinks; otherwise stored.
    public func write() throws -> Data {
        var out = Data()

        struct CDRecord {
            let name: String
            let method: UInt16
            let crc: UInt32
            let compSize: UInt32
            let uncSize: UInt32
            let lhOffset: UInt32
            let dosDate: UInt16
            let dosTime: UInt16
        }

        var records: [CDRecord] = []
        records.reserveCapacity(entries.count)

        for entry in entries {
            let lhOffset = UInt32(out.count)
            let nameBytes = Array(entry.name.utf8)
            let crc = entry.data.isEmpty ? 0 : ZipArchive.crc32(entry.data)
            let (date, time) = ZipArchive.dateToDosDateTime(entry.modificationDate)

            // Try deflate. If output isn't smaller, store.
            var method: UInt16 = 0
            var payload = entry.data
            if !entry.data.isEmpty {
                if let deflated = try? ZipArchive.deflate(entry.data), deflated.count < entry.data.count {
                    method = 8
                    payload = deflated
                }
            }
            let compSize = UInt32(payload.count)
            let uncSize  = UInt32(entry.data.count)

            // Local file header.
            var lfh = Data()
            appendU32LE(&lfh, 0x04034b50)         // signature
            appendU16LE(&lfh, 20)                  // version needed (2.0)
            appendU16LE(&lfh, 0x0800)              // gp flag: language encoding (UTF-8)
            appendU16LE(&lfh, method)
            appendU16LE(&lfh, time)
            appendU16LE(&lfh, date)
            appendU32LE(&lfh, crc)
            appendU32LE(&lfh, compSize)
            appendU32LE(&lfh, uncSize)
            appendU16LE(&lfh, UInt16(nameBytes.count))
            appendU16LE(&lfh, 0)                   // extra length
            lfh.append(contentsOf: nameBytes)

            out.append(lfh)
            out.append(payload)

            records.append(CDRecord(
                name: entry.name, method: method, crc: crc,
                compSize: compSize, uncSize: uncSize,
                lhOffset: lhOffset, dosDate: date, dosTime: time
            ))
        }

        // Central directory.
        let cdStart = UInt32(out.count)
        for r in records {
            let nameBytes = Array(r.name.utf8)
            var cdh = Data()
            appendU32LE(&cdh, 0x02014b50)
            appendU16LE(&cdh, 20)                  // version made by
            appendU16LE(&cdh, 20)                  // version needed
            appendU16LE(&cdh, 0x0800)              // gp flag (UTF-8)
            appendU16LE(&cdh, r.method)
            appendU16LE(&cdh, r.dosTime)
            appendU16LE(&cdh, r.dosDate)
            appendU32LE(&cdh, r.crc)
            appendU32LE(&cdh, r.compSize)
            appendU32LE(&cdh, r.uncSize)
            appendU16LE(&cdh, UInt16(nameBytes.count))
            appendU16LE(&cdh, 0)                   // extra
            appendU16LE(&cdh, 0)                   // comment
            appendU16LE(&cdh, 0)                   // disk number
            appendU16LE(&cdh, 0)                   // internal attrs
            appendU32LE(&cdh, 0)                   // external attrs
            appendU32LE(&cdh, r.lhOffset)
            cdh.append(contentsOf: nameBytes)

            out.append(cdh)
        }
        let cdSize = UInt32(out.count) - cdStart

        // EOCD.
        var eocd = Data()
        appendU32LE(&eocd, 0x06054b50)
        appendU16LE(&eocd, 0)                      // disk
        appendU16LE(&eocd, 0)                      // start disk
        appendU16LE(&eocd, UInt16(records.count))  // entries on this disk
        appendU16LE(&eocd, UInt16(records.count))  // total entries
        appendU32LE(&eocd, cdSize)
        appendU32LE(&eocd, cdStart)
        appendU16LE(&eocd, 0)                      // comment length
        out.append(eocd)

        return out
    }

    // MARK: - DEFLATE / INFLATE via Compression framework

    private static func deflate(_ src: Data) throws -> Data {
        return try transform(src, operation: COMPRESSION_STREAM_ENCODE)
    }

    private static func inflate(_ src: Data, expectedSize: Int) throws -> Data {
        return try transform(src, operation: COMPRESSION_STREAM_DECODE, hint: expectedSize)
    }

    private static func transform(_ src: Data,
                                  operation: compression_stream_operation,
                                  hint: Int = 0) throws -> Data
    {
        guard !src.isEmpty else { return Data() }
        let bufferSize = max(64 * 1024, hint)
        let dst = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { dst.deallocate() }

        var stream = compression_stream(
            dst_ptr: dst,
            dst_size: bufferSize,
            src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!,
            src_size: 0,
            state: nil
        )
        var status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status == COMPRESSION_STATUS_OK else {
            if operation == COMPRESSION_STREAM_ENCODE { throw ZipError.compressFailed }
            else { throw ZipError.decompressFailed }
        }
        defer { compression_stream_destroy(&stream) }

        return try src.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Data in
            stream.src_ptr  = raw.bindMemory(to: UInt8.self).baseAddress!
            stream.src_size = raw.count
            stream.dst_ptr  = dst
            stream.dst_size = bufferSize

            var output = Data()
            let flags: Int32 = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)

            while true {
                status = compression_stream_process(&stream, flags)
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = bufferSize - stream.dst_size
                    if produced > 0 {
                        output.append(dst, count: produced)
                    }
                    if status == COMPRESSION_STATUS_END { return output }
                    stream.dst_ptr = dst
                    stream.dst_size = bufferSize
                default:
                    if operation == COMPRESSION_STREAM_ENCODE {
                        throw ZipError.compressFailed
                    } else {
                        throw ZipError.decompressFailed
                    }
                }
            }
        }
    }

    // MARK: - CRC32 (zlib polynomial 0xEDB88320)

    private static let crcTable: [UInt32] = {
        var t = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            t[i] = c
        }
        return t
    }()

    fileprivate static func crc32(_ data: Data) -> UInt32 {
        var c: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let base = raw.bindMemory(to: UInt8.self)
            for i in 0..<base.count {
                c = crcTable[Int((c ^ UInt32(base[i])) & 0xFF)] ^ (c >> 8)
            }
        }
        return c ^ 0xFFFFFFFF
    }

    // MARK: - DOS time helpers

    fileprivate static func dosDateTimeToDate(dosDate: UInt16, dosTime: UInt16) -> Date {
        let year   = Int((dosDate >> 9) & 0x7F) + 1980
        let month  = Int((dosDate >> 5) & 0xF)
        let day    = Int(dosDate & 0x1F)
        let hour   = Int((dosTime >> 11) & 0x1F)
        let minute = Int((dosTime >> 5) & 0x3F)
        let second = Int((dosTime & 0x1F) * 2)

        var comps = DateComponents()
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = year; comps.month = max(1, month); comps.day = max(1, day)
        comps.hour = hour; comps.minute = minute; comps.second = second
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    fileprivate static func dateToDosDateTime(_ date: Date) -> (date: UInt16, time: UInt16) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year   = max(1980, c.year ?? 1980)
        let dosY   = UInt16(year - 1980) & 0x7F
        let dosM   = UInt16(c.month ?? 1) & 0xF
        let dosD   = UInt16(c.day ?? 1) & 0x1F
        let dosH   = UInt16(c.hour ?? 0) & 0x1F
        let dosMi  = UInt16(c.minute ?? 0) & 0x3F
        let dosS   = UInt16((c.second ?? 0) / 2) & 0x1F
        let dosDate = (dosY << 9) | (dosM << 5) | dosD
        let dosTime = (dosH << 11) | (dosMi << 5) | dosS
        return (dosDate, dosTime)
    }
}

// MARK: - Endian append helpers

private func appendU16LE(_ d: inout Data, _ v: UInt16) {
    d.append(UInt8(v & 0xFF))
    d.append(UInt8((v >> 8) & 0xFF))
}
private func appendU32LE(_ d: inout Data, _ v: UInt32) {
    for i in 0..<4 {
        d.append(UInt8((v >> (8 * UInt32(i))) & 0xFF))
    }
}
