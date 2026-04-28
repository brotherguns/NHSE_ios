//
//  InventoryEditorView.swift
//  NHSEiOS
//

import SwiftUI

struct InventoryEditorView: View {

    @EnvironmentObject private var session: SaveSession

    enum Kind: String, Hashable {
        case pocket, bag, chest
        var title: String {
            switch self {
            case .pocket: return "Pocket (1–20)"
            case .bag:    return "Bag (21–40)"
            case .chest:  return "Storage chest"
            }
        }
    }

    let player: Player
    let kind: Kind

    @State private var slots: [Item] = []
    @State private var didLoad = false

    private var maxSlots: Int {
        guard let o = player.personal.offsets else { return 0 }
        switch kind {
        case .pocket: return PersonalOffsets.pockets2Count
        case .bag:    return PersonalOffsets.pockets1Count
        case .chest:  return o.itemChestCount
        }
    }

    var body: some View {
        List {
            if player.personal.offsets == nil {
                Section { Text("Editing not supported for this revision (read-only).") }
            }

            Section {
                let occupied = slots.prefix(maxSlots).filter { !$0.isEmpty }.count
                LabeledContent("Slots used", value: "\(occupied) / \(maxSlots)")
            }

            ForEach(slots.indices, id: \.self) { i in
                NavigationLink {
                    SlotEditView(slotIndex: i, item: bindingForSlot(i))
                } label: {
                    SlotRow(index: i + 1, item: slots[i])
                }
            }
        }
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadSlots)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    commitSlots()
                } label: {
                    Label("Apply", systemImage: "checkmark")
                }
                .disabled(player.personal.offsets == nil)
            }
        }
    }

    // MARK: - Loading & saving

    private func loadSlots() {
        guard !didLoad else { return }
        didLoad = true
        switch kind {
        case .pocket: slots = player.personal.pocket
        case .bag:    slots = player.personal.bag
        case .chest:
            // Chest can be huge (5000–9000). Load only the first 200 to keep
            // the SwiftUI List responsive in this MVP. We still write back the
            // whole array (untouched tail) on commit.
            slots = Array(player.personal.itemChest.prefix(200))
        }
    }

    private func bindingForSlot(_ i: Int) -> Binding<Item> {
        return Binding(
            get: {
                guard slots.indices.contains(i) else {
                    return Item(itemId: Item.none)
                }
                return slots[i]
            },
            set: { newValue in
                guard slots.indices.contains(i) else { return }
                slots[i] = newValue
            }
        )
    }

    private func commitSlots() {
        guard player.personal.offsets != nil else { return }
        switch kind {
        case .pocket:
            player.personal.pocket = padded(slots, to: PersonalOffsets.pockets2Count)
        case .bag:
            player.personal.bag    = padded(slots, to: PersonalOffsets.pockets1Count)
        case .chest:
            // Write back only what we loaded; everything past `slots.count`
            // remains untouched on disk.
            var existing = player.personal.itemChest
            for (i, v) in slots.enumerated() where i < existing.count {
                existing[i] = v
            }
            player.personal.itemChest = existing
        }
        session.bumpVersion()
    }

    private func padded(_ items: [Item], to count: Int) -> [Item] {
        if items.count >= count { return Array(items.prefix(count)) }
        return items + Array(repeating: Item(itemId: Item.none), count: count - items.count)
    }
}

// MARK: - Slot row

private struct SlotRow: View {
    let index: Int
    let item: Item
    var body: some View {
        HStack {
            Text(String(format: "%02d", index))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(idLabel)
                    .font(.body.monospaced())
                Text(detailLabel)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var idLabel: String {
        if item.isEmpty { return "(empty)" }
        return String(format: "0x%04X", item.itemId)
    }

    private var detailLabel: String {
        if item.isEmpty { return "—" }
        return String(format: "free=%d sys=%02X add=%02X",
                      item.freeParam, item.systemParam, item.additionalParam)
    }
}

// MARK: - Slot editor

private struct SlotEditView: View {
    let slotIndex: Int
    @Binding var item: Item

    @State private var idText: String = ""
    @State private var freeText: String = ""
    @State private var sysText: String = ""
    @State private var addText: String = ""

    var body: some View {
        Form {
            Section("Item") {
                HStack {
                    Text("ID (hex)")
                    Spacer()
                    TextField("FFFE", text: $idText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("FreeParam (signed int32)")
                    Spacer()
                    TextField("0", text: $freeText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("SystemParam (hex byte)")
                    Spacer()
                    TextField("00", text: $sysText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("AdditionalParam (hex byte)")
                    Spacer()
                    TextField("00", text: $addText)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button("Apply changes") { applyChanges() }
                Button(role: .destructive) {
                    item = Item(itemId: Item.none)
                    refreshFromItem()
                } label: { Text("Clear slot") }
            }

            Section("Quick presets") {
                Button("100,000 bells (0x1180)") {
                    item = Item(itemId: 0x1180, systemParam: 0, additionalParam: 0,
                                freeParam: 100_000)
                    refreshFromItem()
                }
                Button("99,000 bells bag (0x1471)") {
                    item = Item(itemId: 0x1471, systemParam: 0, additionalParam: 0,
                                freeParam: 99_000)
                    refreshFromItem()
                }
            }
        }
        .navigationTitle("Slot \(slotIndex + 1)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshFromItem)
    }

    private func refreshFromItem() {
        idText   = String(format: "%04X", item.itemId)
        freeText = String(item.freeParam)
        sysText  = String(format: "%02X", item.systemParam)
        addText  = String(format: "%02X", item.additionalParam)
    }

    private func applyChanges() {
        if let v = UInt16(idText.trimmingCharacters(in: .whitespaces), radix: 16) {
            item.itemId = v
        }
        if let v = Int32(freeText.trimmingCharacters(in: .whitespaces)) {
            item.freeParam = v
        }
        if let v = UInt8(sysText.trimmingCharacters(in: .whitespaces), radix: 16) {
            item.systemParam = v
        }
        if let v = UInt8(addText.trimmingCharacters(in: .whitespaces), radix: 16) {
            item.additionalParam = v
        }
        refreshFromItem()
    }
}
