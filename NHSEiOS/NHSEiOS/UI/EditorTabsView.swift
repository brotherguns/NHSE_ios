//
//  EditorTabsView.swift
//  NHSEiOS
//

import SwiftUI

struct EditorTabsView: View {

    @EnvironmentObject private var session: SaveSession

    var body: some View {
        TabView {
            NavigationStack { OverviewView() }
                .tabItem { Label("Save", systemImage: "house.fill") }

            NavigationStack { PlayersListView() }
                .tabItem { Label("Players", systemImage: "person.fill") }

            NavigationStack { VillagersView() }
                .tabItem { Label("Villagers", systemImage: "pawprint.fill") }

            NavigationStack { ExportView() }
                .tabItem { Label("Export", systemImage: "square.and.arrow.up.fill") }
        }
    }
}

// MARK: - Overview

private struct OverviewView: View {
    @EnvironmentObject private var session: SaveSession

    var body: some View {
        Form {
            if let save = session.save {
                Section("Detected") {
                    LabeledContent("Revision", value: save.main.revision.displayName)
                    LabeledContent("Editing supported",
                                   value: save.main.revision.isEditingSupported ? "Yes" : "No (read-only)")
                    LabeledContent("Hemisphere",
                                   value: save.main.hemisphere?.displayName ?? "—")
                    LabeledContent("Players", value: "\(save.players.count)")
                    LabeledContent("Villagers (slots)", value: "\(MainSaveOffsets.villagerCount)")
                }

                if let town = save.players.first?.personal.townName, !town.isEmpty {
                    Section("Town") {
                        LabeledContent("Name", value: town)
                        LabeledContent("Town ID",
                                       value: String(format: "0x%08X",
                                                     save.players.first?.personal.townID ?? 0))
                    }
                }

                Section("Sizes") {
                    let mainSize = save.main.data.count
                    LabeledContent("main.dat", value: String(format: "0x%X (%d B)", mainSize, mainSize))
                    LabeledContent("size table OK",
                                   value: save.validateSizes() ? "Yes" : "Mismatch")
                }

                if !session.notes.isEmpty {
                    Section("Notes") {
                        ForEach(session.notes, id: \.self) { n in
                            Text(n).font(.callout)
                        }
                    }
                }
            } else {
                Text("No save loaded.")
            }

            Section {
                Button(role: .destructive) {
                    session.unload()
                } label: {
                    Label("Close save", systemImage: "xmark.circle")
                }
            }
        }
        .navigationTitle("Overview")
    }
}

// MARK: - Players list

private struct PlayersListView: View {
    @EnvironmentObject private var session: SaveSession

    var body: some View {
        List {
            if let save = session.save {
                ForEach(Array(save.players.enumerated()), id: \.offset) { idx, player in
                    NavigationLink(value: idx) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(player.personal.playerName.isEmpty
                                 ? "(unnamed)" : player.personal.playerName)
                                .font(.headline)
                            HStack(spacing: 6) {
                                Text(player.directoryName)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                if let w = player.personal.wallet {
                                    Text("•").foregroundStyle(.secondary)
                                    Text("\(w.value)") +
                                    Text(" bells").foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            } else {
                Text("No save loaded.")
            }
        }
        .navigationTitle("Players")
        .navigationDestination(for: Int.self) { idx in
            PlayerEditorView(playerIndex: idx)
        }
    }
}
