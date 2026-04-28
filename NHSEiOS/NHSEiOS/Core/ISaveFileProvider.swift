//
//  ISaveFileProvider.swift
//  NHSEiOS
//
//  Abstraction over the storage backing a save (folder on disk or in-memory zip).
//

import Foundation

public protocol ISaveFileProvider: AnyObject {
    /// Read the named file (relative path). Throws if missing or unreadable.
    func readFile(_ relativePath: String) throws -> Data

    /// Write the named file (relative path). Replaces any existing entry.
    func writeFile(_ relativePath: String, data: Data) throws

    /// Whether the provider currently has an entry at `relativePath`.
    func fileExists(_ relativePath: String) -> Bool

    /// Names (not full paths) of immediate subdirectories matching the simple
    /// "wildcard*" pattern (only the trailing '*' is supported).
    func directories(matching pattern: String) -> [String]

    /// Return a sub-provider scoped to `subdirectory` inside this provider.
    func subProvider(_ subdirectory: String) -> ISaveFileProvider

    /// Persist any pending writes. No-op for folder providers; rebuilds the
    /// archive for zip providers.
    func flush() throws
}

public enum ProviderError: Error, CustomStringConvertible {
    case fileMissing(String)
    case io(String)

    public var description: String {
        switch self {
        case .fileMissing(let p): return "File not found: \(p)"
        case .io(let s):          return "I/O error: \(s)"
        }
    }
}
