import SwiftUI
import PartyCore

/// Create or edit an app zone: pick lights from ANY connected system, in any
/// combination, and order them the way the gradient should flow.
public struct ZoneEditorView: View {
    @Environment(LightsStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private let existing: Zone?
    @State private var name: String
    @State private var symbolName: String
    @State private var selected: [LightID]

    private static let symbols = [
        "lamp.ceiling.inverse", "sofa.fill", "bed.double.fill", "fork.knife",
        "desktopcomputer", "tv.fill", "party.popper.fill", "sparkles",
        "tree.fill", "house.fill", "moon.stars.fill", "music.note",
    ]

    public init(existing: Zone?) {
        self.existing = existing
        _name = State(initialValue: existing?.name ?? "")
        _symbolName = State(initialValue: existing?.symbolName ?? "lamp.ceiling.inverse")
        _selected = State(initialValue: existing?.lightIDs ?? [])
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Zone") {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("zone-name-field")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Self.symbols, id: \.self) { symbol in
                                Button {
                                    symbolName = symbol
                                } label: {
                                    Image(systemName: symbol)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            symbolName == symbol ? PartyTheme.accent.opacity(0.35) : Color.clear,
                                            in: .circle
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if !suggestions.isEmpty && existing == nil {
                    Section("Start from a room") {
                        ForEach(suggestions) { group in
                            Button {
                                if name.isEmpty { name = group.name }
                                selected = group.lightIDs
                            } label: {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    Text("\(group.lightIDs.count) lights")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Lights (\(selected.count) selected)") {
                    ForEach(groupedLights, id: \.0) { sectionName, lights in
                        DisclosureGroup(sectionName) {
                            ForEach(lights) { light in
                                lightRow(light)
                            }
                        }
                    }
                }

                if selected.count > 1 {
                    Section {
                        selectedOrderEditor
                    } header: {
                        Text("Gradient order")
                    } footer: {
                        Text("Gradients sweep through lights in this order. Drag to rearrange.")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(existing == nil ? "New Zone" : "Edit Zone")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selected.isEmpty)
                        .accessibilityIdentifier("zone-save")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 480)
        #endif
    }

    /// Visible lights grouped by provider + room for the picker.
    private var groupedLights: [(String, [Light])] {
        let groups = Dictionary(grouping: store.visibleLights) { light in
            "\(light.id.provider.displayName)\(light.room.map { " · \($0)" } ?? "")"
        }
        return groups.sorted { $0.key < $1.key }
    }

    private var suggestions: [ProviderGroup] {
        store.nativeGroups.values.flatMap { $0 }
    }

    private func lightRow(_ light: Light) -> some View {
        Button {
            if let index = selected.firstIndex(of: light.id) {
                selected.remove(at: index)
            } else {
                selected.append(light.id)
            }
        } label: {
            HStack {
                Image(systemName: selected.contains(light.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected.contains(light.id) ? PartyTheme.accent : .secondary)
                Text(light.name)
                Spacer()
                if light.capabilities.contains(.nativeGradient) {
                    Image(systemName: "light.strip.2")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedOrderEditor: some View {
        let byID = Dictionary(uniqueKeysWithValues: store.lights.map { ($0.id, $0) })
        return List {
            ForEach(selected, id: \.self) { id in
                HStack {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.tertiary)
                    Text(byID[id]?.name ?? id.raw)
                }
            }
            .onMove { source, destination in
                selected.move(fromOffsets: source, toOffset: destination)
            }
        }
        .frame(minHeight: CGFloat(selected.count) * 38 + 10)
    }

    private func save() {
        var zone = existing ?? Zone(name: name)
        zone.name = name.trimmingCharacters(in: .whitespaces)
        zone.symbolName = symbolName
        zone.lightIDs = selected
        if existing == nil {
            store.zoneStore.add(zone)
        } else {
            store.zoneStore.update(zone)
        }
        store.reconcile()
        dismiss()
    }
}
