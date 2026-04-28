//
//  ExportView.swift
//  NHSEiOS
//

import SwiftUI
import UIKit

struct ExportView: View {

    @EnvironmentObject private var session: SaveSession

    @State private var isWorking = false
    @State private var lastExportURL: URL?
    @State private var errorMessage: String?
    @State private var showShare = false
    @State private var seedText: String = "DEADBEEF"

    var body: some View {
        Form {
            Section("Encryption seed") {
                HStack {
                    Text("Seed (hex u32)")
                    Spacer()
                    TextField("DEADBEEF", text: $seedText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                Text("Any 32-bit value works. The game re-derives the AES key/counter from this seed plus the preserved version-data bytes 0..0x100 of the original header.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Export") {
                Button {
                    Task { await runExport() }
                } label: {
                    if isWorking {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Re-hashing & re-encrypting…")
                        }
                    } else {
                        Label("Build edited save .zip", systemImage: "shippingbox.and.arrow.backward")
                    }
                }
                .disabled(isWorking || session.save == nil)

                if let err = errorMessage {
                    Text(err)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }

            if !session.lastSkippedRehash.isEmpty {
                Section("Skipped during last save") {
                    ForEach(session.lastSkippedRehash, id: \.self) { name in
                        Text(name).font(.caption.monospaced())
                    }
                    Text("These files have no Murmur3 region table for their size in this app build. The game may reject them.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let url = lastExportURL {
                Section("Latest output") {
                    LabeledContent("Path", value: url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button {
                        showShare = true
                    } label: {
                        Label("Share / save to Files", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle("Export")
        .sheet(isPresented: $showShare) {
            if let url = lastExportURL {
                ShareSheet(items: [url])
            }
        }
    }

    @MainActor
    private func runExport() async {
        errorMessage = nil
        guard session.save != nil else { return }

        let seed = parseSeed(seedText)
        isWorking = true
        defer { isWorking = false }

        do {
            // Yield once so the spinner can render before the synchronous
            // encryption pass kicks off.
            await Task.yield()
            let data: Data = try session.exportZip(seed: seed)

            let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let stamp = Int(Date().timeIntervalSince1970)
            let url = cache.appendingPathComponent("NHSE-export-\(stamp).zip")
            try data.write(to: url, options: .atomic)
            lastExportURL = url
            showShare = true
        } catch {
            errorMessage = (error as? CustomStringConvertible)?.description ?? error.localizedDescription
        }
    }

    private func parseSeed(_ s: String) -> UInt32 {
        var t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("0x") || t.hasPrefix("0X") {
            t = String(t.dropFirst(2))
        }
        if let v = UInt32(t, radix: 16) { return v }
        return 0xDEADBEEF
    }
}

// MARK: - UIActivityViewController bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_: UIActivityViewController, context: Context) {}
}
