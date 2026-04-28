//
//  CompanionFiles.swift
//  NHSEiOS
//
//  Thin wrappers around the remaining per-player save files. These are loaded
//  primarily so we can decrypt → re-hash → re-encrypt them on save; we don't
//  expose detailed editing surface for them in this MVP.
//

import Foundation

public final class PostBox: EncryptedFilePair {
    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: PostBox.fileName)
    }
    public static let fileName = "postbox"
}

public final class PhotoStudioIsland: EncryptedFilePair {
    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: PhotoStudioIsland.fileName)
    }
    public static let fileName = "photo_studio_island"
}

public final class Profile: EncryptedFilePair {
    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: Profile.fileName)
    }
    public static let fileName = "profile"
}

public final class WhereAreN: EncryptedFilePair {
    public init(provider: ISaveFileProvider) throws {
        try super.init(provider: provider, name: WhereAreN.fileName)
    }
    public static let fileName = "wherearen"
}
