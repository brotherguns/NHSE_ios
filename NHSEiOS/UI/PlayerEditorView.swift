//
//  PlayerEditorView.swift
//  NHSEiOS
//

import SwiftUI

struct PlayerEditorView: View {

    @EnvironmentObject private var session: SaveSession
    let playerIndex: Int

    private var player: Player? {
        guard let save = session.save,
              playerIndex >= 0, playerIndex < save.players.count
        else { return nil }
        return save.players[playerIndex]
    }

    var body: some View {
        Group {
            if let player = player {
                Form {
                    identitySection(player)
                    currencySection(player)
                    inventorySection(player)
                }
            } else {
                Text("Player not found.")
            }
        }
        .navigationTitle(player?.personal.playerName ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private func identitySection(_ player: Player) -> some View {
        Section("Identity") {
            TextFieldRow(
                title: "Player name",
                text: Binding(
                    get: { player.personal.playerName },
                    set: { player.personal.playerName = $0; session.bumpVersion() }
                ),
                placeholder: "(name)",
                allowEdit: player.personal.offsets != nil
            )
            TextFieldRow(
                title: "Town name",
                text: Binding(
                    get: { player.personal.townName },
                    set: { player.personal.townName = $0; session.bumpVersion() }
                ),
                placeholder: "(town)",
                allowEdit: player.personal.offsets != nil
            )
            HexFieldRow(
                title: "Player ID",
                value: Binding(
                    get: { player.personal.playerID },
                    set: { player.personal.playerID = $0; session.bumpVersion() }
                ),
                allowEdit: player.personal.offsets != nil
            )
            HexFieldRow(
                title: "Town ID",
                value: Binding(
                    get: { player.personal.townID },
                    set: { player.personal.townID = $0; session.bumpVersion() }
                ),
                allowEdit: player.personal.offsets != nil
            )
        }
    }

    private func currencySection(_ player: Player) -> some View {
        Section("Currency") {
            EncryptedIntRow(
                title: "Wallet (bells)",
                getter: { player.personal.wallet },
                setter: { player.personal.wallet = $0; session.bumpVersion() }
            )
            EncryptedIntRow(
                title: "Bank (bells)",
                getter: { player.personal.bank },
                setter: { player.personal.bank = $0; session.bumpVersion() }
            )
            EncryptedIntRow(
                title: "Nook Miles",
                getter: { player.personal.nookMiles },
                setter: { player.personal.nookMiles = $0; session.bumpVersion() }
            )
            EncryptedIntRow(
                title: "Total Nook Miles",
                getter: { player.personal.totalNookMiles },
                setter: { player.personal.totalNookMiles = $0; session.bumpVersion() }
            )
        }
    }

    private func inventorySection(_ player: Player) -> some View {
        Section("Inventory") {
            NavigationLink {
                InventoryEditorView(player: player, kind: .pocket)
            } label: {
                Label("Pocket (1–20)", systemImage: "bag")
            }
            NavigationLink {
                InventoryEditorView(player: player, kind: .bag)
            } label: {
                Label("Bag (21–40)", systemImage: "bag.badge.plus")
            }
            NavigationLink {
                InventoryEditorView(player: player, kind: .chest)
            } label: {
                Label("Storage chest", systemImage: "shippingbox")
            }
        }
    }
}

// MARK: - Reusable rows

private struct TextFieldRow: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let allowEdit: Bool
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if allowEdit {
                TextField(placeholder, text: $text)
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                Text(text.isEmpty ? "—" : text).foregroundStyle(.secondary)
            }
        }
    }
}

private struct HexFieldRow: View {
    let title: String
    @Binding var value: UInt32
    let allowEdit: Bool
    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if allowEdit {
                TextField("0x…", text: $text, onCommit: commit)
                    .keyboardType(.asciiCapable)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .onAppear { text = String(format: "0x%08X", value) }
                    .onChange(of: value) { _, newVal in
                        text = String(format: "0x%08X", newVal)
                    }
            } else {
                Text(String(format: "0x%08X", value)).foregroundStyle(.secondary)
            }
        }
    }

    private func commit() {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let body: String = trimmed.hasPrefix("0x") ? String(trimmed.dropFirst(2)) : trimmed
        if let v = UInt32(body, radix: 16) {
            value = v
        }
        text = String(format: "0x%08X", value)
    }
}

private struct EncryptedIntRow: View {
    let title: String
    let getter: () -> EncryptedInt32?
    let setter: (EncryptedInt32) -> Void

    @State private var text: String = ""

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let cur = getter() {
                TextField("0", text: $text, onCommit: commit)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .onAppear {
                        text = String(cur.value)
                    }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    private func commit() {
        guard let cur = getter() else { return }
        let cleaned = text.filter(\.isNumber)
        if let v = UInt32(cleaned) {
            var copy = cur
            copy.value = v
            setter(copy)
        }
        if let cur2 = getter() { text = String(cur2.value) }
    }
}
