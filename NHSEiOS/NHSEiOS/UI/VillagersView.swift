//
//  VillagersView.swift
//  NHSEiOS
//

import SwiftUI

struct VillagersView: View {

    @EnvironmentObject private var session: SaveSession

    var body: some View {
        List {
            if let save = session.save {
                ForEach(0..<MainSaveOffsets.villagerCount, id: \.self) { i in
                    NavigationLink(value: i) {
                        VillagerRow(save: save, index: i)
                    }
                }
            } else {
                Text("No save loaded.")
            }
        }
        .navigationTitle("Villagers")
        .navigationDestination(for: Int.self) { i in
            VillagerEditView(slotIndex: i)
        }
    }
}

private struct VillagerRow: View {
    let save: HorizonSave
    let index: Int

    var body: some View {
        let v = save.main.villager(at: index)
        HStack(spacing: 10) {
            Text(String(format: "%02d", index + 1))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                if let v = v {
                    if v.isPresent {
                        Text("Code \(v.internalCode)")
                            .font(.body.monospaced())
                        Text(v.personality.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("(empty slot)")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

private struct VillagerEditView: View {

    @EnvironmentObject private var session: SaveSession
    let slotIndex: Int

    @State private var speciesText: String = ""
    @State private var variantText: String = ""
    @State private var personality: VillagerPersonality = .normal
    @State private var loaded = false

    var body: some View {
        Form {
            Section("Identity") {
                HStack {
                    Text("Species (hex byte)")
                    Spacer()
                    TextField("00", text: $speciesText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Variant (hex byte)")
                    Spacer()
                    TextField("00", text: $variantText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Personality", selection: $personality) {
                    ForEach(VillagerPersonality.allCases, id: \.self) { p in
                        Text(p.displayName).tag(p)
                    }
                }
            }

            Section {
                Button("Apply") { applyChanges() }
            }
        }
        .navigationTitle("Villager \(slotIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
    }

    private func load() {
        guard !loaded, let save = session.save,
              let v = save.main.villager(at: slotIndex)
        else { return }
        speciesText = String(format: "%02X", v.species)
        variantText = String(format: "%02X", v.variant)
        personality = v.personality
        loaded = true
    }

    private func applyChanges() {
        guard let save = session.save,
              var v = save.main.villager(at: slotIndex)
        else { return }
        if let s = UInt8(speciesText.trimmingCharacters(in: .whitespaces), radix: 16) {
            v.species = s
        }
        if let vv = UInt8(variantText.trimmingCharacters(in: .whitespaces), radix: 16) {
            v.variant = vv
        }
        v.personality = personality
        save.main.setVillager(v, at: slotIndex)
        session.bumpVersion()

        // Re-read so the textfields show the now-canonical values.
        if let nv = save.main.villager(at: slotIndex) {
            speciesText = String(format: "%02X", nv.species)
            variantText = String(format: "%02X", nv.variant)
            personality = nv.personality
        }
    }
}
