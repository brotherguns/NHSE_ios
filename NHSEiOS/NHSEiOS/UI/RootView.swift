//
//  RootView.swift
//  NHSEiOS
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {

    @EnvironmentObject private var session: SaveSession

    @State private var showingFolderImporter = false
    @State private var showingZipImporter = false

    var body: some View {
        Group {
            switch session.status {
            case .idle:
                idleView
            case .loading:
                loadingView
            case .loaded:
                if session.save != nil {
                    EditorTabsView()
                } else {
                    idleView
                }
            case .error(let msg):
                errorView(msg)
            }
        }
        .fileImporter(
            isPresented: $showingFolderImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result, isFolder: true)
        }
        .fileImporter(
            isPresented: $showingZipImporter,
            allowedContentTypes: [.zip, UTType(filenameExtension: "zip") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result, isFolder: false)
        }
    }

    // MARK: - Subviews

    private var idleView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("NHSE iOS")
                        .font(.largeTitle).bold()
                    Text("Animal Crossing: New Horizons save editor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showingFolderImporter = true
                    } label: {
                        Label("Open save folder…", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingZipImporter = true
                    } label: {
                        Label("Open save .zip…", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 32)

                Text("Pick the folder (or zip) that contains main.dat / mainHeader.dat plus the Villager0..7 subfolders.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("NHSE iOS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("Decrypting save…")
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Couldn't load save")
                .font(.title2).bold()
            Text(msg)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again") {
                session.unload()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Importer handler

    private func handleImport(_ result: Result<[URL], Error>, isFolder: Bool) {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            // Acquire security-scoped access for the duration of the load.
            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart { url.stopAccessingSecurityScopedResource() }
            }

            // For zip: copy the file into our sandbox first so we can read it
            // outside the security scope (the loader is async and may outlast it).
            if !isFolder {
                let copy = try copyIntoSandbox(url)
                session.load(zipURL: copy)
                return
            }

            // For folder: stage a copy into our sandbox so the in-memory edits
            // and re-export work cleanly without us having to re-acquire the
            // security scope on save.
            let copy = try stageFolderIntoSandbox(url)
            session.load(folderURL: copy)
        } catch {
            session.unload()
        }
    }

    private func copyIntoSandbox(_ src: URL) throws -> URL {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dst = cache.appendingPathComponent("import-\(UUID().uuidString)-\(src.lastPathComponent)")
        if FileManager.default.fileExists(atPath: dst.path) {
            try FileManager.default.removeItem(at: dst)
        }
        try FileManager.default.copyItem(at: src, to: dst)
        return dst
    }

    private func stageFolderIntoSandbox(_ src: URL) throws -> URL {
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let staging = cache.appendingPathComponent("save-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try copyContents(of: src, into: staging)
        return staging
    }

    private func copyContents(of src: URL, into dst: URL) throws {
        let fm = FileManager.default
        let names = try fm.contentsOfDirectory(atPath: src.path)
        for n in names {
            let s = src.appendingPathComponent(n)
            let d = dst.appendingPathComponent(n)
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: s.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    try fm.createDirectory(at: d, withIntermediateDirectories: true)
                    try copyContents(of: s, into: d)
                } else {
                    try fm.copyItem(at: s, to: d)
                }
            }
        }
    }
}
