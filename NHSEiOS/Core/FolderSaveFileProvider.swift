//
//  FolderSaveFileProvider.swift
//  NHSEiOS
//
//  Reads a save tree from / writes a save tree to a real on-disk folder.
//  All paths are interpreted relative to `rootURL`.
//

import Foundation

public final class FolderSaveFileProvider: ISaveFileProvider {

    public let rootURL: URL

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    public func readFile(_ relativePath: String) throws -> Data {
        let url = rootURL.appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ProviderError.fileMissing(relativePath)
        }
        do {
            return try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            throw ProviderError.io(error.localizedDescription)
        }
    }

    public func writeFile(_ relativePath: String, data: Data) throws {
        let url = rootURL.appendingPathComponent(relativePath)
        let parent = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: parent,
                                                    withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            throw ProviderError.io(error.localizedDescription)
        }
    }

    public func fileExists(_ relativePath: String) -> Bool {
        let url = rootURL.appendingPathComponent(relativePath)
        return FileManager.default.fileExists(atPath: url.path)
    }

    public func directories(matching pattern: String) -> [String] {
        // Support "Prefix*" only.
        let prefix: String
        if pattern.hasSuffix("*") {
            prefix = String(pattern.dropLast())
        } else {
            prefix = pattern
        }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: rootURL.path) else {
            return []
        }
        var out: [String] = []
        for name in names {
            let fullURL = rootURL.appendingPathComponent(name)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: fullURL.path, isDirectory: &isDir),
               isDir.boolValue,
               name.hasPrefix(prefix)
            {
                out.append(name)
            }
        }
        out.sort()
        return out
    }

    public func subProvider(_ subdirectory: String) -> ISaveFileProvider {
        let sub = rootURL.appendingPathComponent(subdirectory)
        return FolderSaveFileProvider(rootURL: sub)
    }

    public func flush() throws {
        // Writes are immediate.
    }
}
