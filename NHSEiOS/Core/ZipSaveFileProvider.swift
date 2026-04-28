//
//  ZipSaveFileProvider.swift
//  NHSEiOS
//
//  ISaveFileProvider implementation backed by an in-memory ZipArchive.
//  Supports a sub-provider rooted at a relative path, so Player.ReadMany
//  can scope into "Villager0/", "Villager1/", etc.
//

import Foundation

public final class ZipSaveFileProvider: ISaveFileProvider {

    public let archive: ZipArchive
    /// Trailing-slash-terminated zip path prefix this provider is rooted at.
    public let rootPrefix: String

    public init(archive: ZipArchive, rootPrefix: String = "") {
        self.archive = archive
        self.rootPrefix = ZipSaveFileProvider.normalize(rootPrefix)
    }

    /// Convenience: load a zip from disk + autodetect the save root inside it.
    public static func load(from url: URL) throws -> ZipSaveFileProvider {
        let raw = try Data(contentsOf: url)
        let arc = try ZipArchive.read(from: raw)
        let root = detectSaveRoot(in: arc) ?? ""
        return ZipSaveFileProvider(archive: arc, rootPrefix: root)
    }

    // MARK: - ISaveFileProvider

    public func readFile(_ relativePath: String) throws -> Data {
        let key = rootPrefix + relativePath
        if let e = archive.entry(named: key) {
            return e.data
        }
        // Some archives store paths with backslashes; normalize on lookup.
        let alt = key.replacingOccurrences(of: "\\", with: "/")
        if let e = archive.entry(named: alt) {
            return e.data
        }
        throw ProviderError.fileMissing(relativePath)
    }

    public func writeFile(_ relativePath: String, data: Data) throws {
        let key = rootPrefix + relativePath
        if let idx = archive.entries.firstIndex(where: { $0.name == key }) {
            archive.entries[idx].data = data
            archive.entries[idx].modificationDate = Date()
        } else {
            archive.entries.append(ZipEntry(name: key, data: data))
        }
    }

    public func fileExists(_ relativePath: String) -> Bool {
        return archive.entry(named: rootPrefix + relativePath) != nil
    }

    public func directories(matching pattern: String) -> [String] {
        let prefix: String
        if pattern.hasSuffix("*") {
            prefix = String(pattern.dropLast())
        } else {
            prefix = pattern
        }
        var seen = Set<String>()
        for entry in archive.entries {
            guard entry.name.hasPrefix(rootPrefix) else { continue }
            let suffix = String(entry.name.dropFirst(rootPrefix.count))
            // Look for "<dirname>/...".
            guard let slashIdx = suffix.firstIndex(of: "/") else { continue }
            let dirname = String(suffix[..<slashIdx])
            if dirname.hasPrefix(prefix) {
                seen.insert(dirname)
            }
        }
        return seen.sorted()
    }

    public func subProvider(_ subdirectory: String) -> ISaveFileProvider {
        return ZipSaveFileProvider(
            archive: archive,
            rootPrefix: rootPrefix + subdirectory + "/"
        )
    }

    public func flush() throws {
        // The archive lives in memory; the caller is responsible for serialising
        // it via archive.write() and writing to disk.
    }

    // MARK: - Helpers

    private static func normalize(_ prefix: String) -> String {
        var p = prefix.replacingOccurrences(of: "\\", with: "/")
        if !p.isEmpty && !p.hasSuffix("/") {
            p.append("/")
        }
        return p
    }

    /// Try to find the directory inside the zip that contains `main.dat`.
    /// Returns "" if `main.dat` is at the archive root.
    public static func detectSaveRoot(in archive: ZipArchive) -> String? {
        // Look for any entry ending in "main.dat" (and a sibling "mainHeader.dat").
        for entry in archive.entries where entry.name.hasSuffix("main.dat") && !entry.isDirectory {
            let leadingLen = entry.name.count - "main.dat".count
            let leading = String(entry.name.prefix(leadingLen))
            // Confirm sibling.
            if archive.entry(named: leading + "mainHeader.dat") != nil {
                return leading
            }
        }
        return nil
    }
}
