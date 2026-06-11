import SwiftUI
import PartyCore

/// The Gradients tab: built-in + custom palettes, a target zone picker, and a
/// CSS-gradient importer.
public struct GradientsView: View {
    @Environment(LightsStore.self) private var store

    @State private var selectedZoneID: UUID = Zone.allLightsID
    @State private var customPalettes: [Palette] = []
    @State private var importing = false
    @State private var applyConfirmation: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    zonePicker

                    palettesGrid(title: "Party Palettes", palettes: Palette.builtIns)

                    if !customPalettes.isEmpty {
                        palettesGrid(title: "Your Gradients", palettes: customPalettes, deletable: true)
                    }

                    importButton
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(PartyBackground())
            .navigationTitle("Gradients")
            .sheet(isPresented: $importing) {
                ImportGradientSheet { palette in
                    customPalettes.append(palette)
                    persistCustomPalettes()
                }
            }
            .onAppear(perform: loadCustomPalettes)
            .overlay(alignment: .bottom) {
                if let message = applyConfirmation {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.tint(PartyTheme.accent.opacity(0.4)), in: .capsule)
                        .padding(.bottom, 18)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    private var zonePicker: some View {
        HStack {
            Label("Apply to", systemImage: "scope")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Picker("Zone", selection: $selectedZoneID) {
                ForEach(store.displayZones) { zone in
                    Text(zone.name).tag(zone.id)
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("gradient-zone-picker")
        }
        .padding(14)
        .partyGlassCard()
    }

    private func palettesGrid(title: String, palettes: [Palette], deletable: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 12)], spacing: 12) {
                ForEach(palettes) { palette in
                    Button {
                        apply(palette)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            PaletteStrip(palette: palette, height: 44)
                            Text(palette.name)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .partyGlassCard()
                    .contextMenu {
                        if deletable {
                            Button("Delete", role: .destructive) {
                                customPalettes.removeAll { $0.id == palette.id }
                                persistCustomPalettes()
                            }
                        }
                    }
                    .accessibilityIdentifier("gradient-card-\(palette.name)")
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            importing = true
        } label: {
            Label("Import CSS Gradient", systemImage: "curlybraces")
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
        }
        .buttonStyle(.glass)
        .controlSize(.regular)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityIdentifier("import-gradient")
    }

    private func apply(_ palette: Palette) {
        let zone = store.zone(withID: selectedZoneID) ?? store.allLightsZone
        Task {
            await store.applyPalette(palette, to: zone)
            withAnimation(.spring) { applyConfirmation = "\(palette.name) → \(zone.name)" }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut) { applyConfirmation = nil }
        }
    }

    private func loadCustomPalettes() {
        customPalettes = SyncEngine.shared.load([Palette].self, forKey: SyncEngine.Keys.customPalettes) ?? []
    }

    private func persistCustomPalettes() {
        SyncEngine.shared.save(customPalettes, forKey: SyncEngine.Keys.customPalettes)
        store.reconcile()
    }
}

/// Paste any CSS gradient (or a bare list of colors) and preview it live.
public struct ImportGradientSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onImport: (Palette) -> Void

    @State private var name = ""
    @State private var css = ""
    @State private var parseError: String?

    public init(onImport: @escaping (Palette) -> Void) {
        self.onImport = onImport
    }

    private var preview: Palette? {
        try? Palette.fromCSS(css, name: name.isEmpty ? "Custom" : name)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Name (e.g. Disco Sunset)", text: $name)
                    .textFieldStyle(.roundedBorder)

                VStack(alignment: .leading, spacing: 8) {
                    Text("CSS gradient or comma-separated colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $css)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 10))
                }

                if let preview {
                    PaletteStrip(palette: preview, height: 36)
                } else if !css.isEmpty {
                    Text(parseError ?? "Keep typing — that doesn't parse yet.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Try: linear-gradient(90deg, #ff2e93, #7b2cbf, #00bbf9)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Import Gradient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let preview {
                            onImport(preview)
                            dismiss()
                        }
                    }
                    .disabled(preview == nil)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 380)
        #endif
        .presentationDetents([.medium, .large])
    }
}
