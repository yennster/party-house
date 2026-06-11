import SwiftUI
import PartyCore

/// The Home tab: every zone as a glass card, whole-house zone pinned on top.
public struct HomeView: View {
    @Environment(LightsStore.self) private var store

    @State private var editingZone: Zone?
    @State private var creatingZone = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    LazyVStack(spacing: 14) {
                        ForEach(store.displayZones) { zone in
                            NavigationLink(value: zone.id) {
                                ZoneCard(zone: zone)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("zone-card-\(zone.name)")
                            .contextMenu {
                                if !zone.isAllLights {
                                    Button("Edit Zone") { editingZone = zone }
                                    Button("Delete Zone", role: .destructive) {
                                        store.zoneStore.delete(zone.id)
                                        store.reconcile()
                                    }
                                }
                            }
                        }

                        addZoneButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                }
            }
            .background(PartyBackground())
            .navigationTitle("Party House")
            .navigationDestination(for: UUID.self) { zoneID in
                if let zone = store.zone(withID: zoneID) {
                    ZoneDetailView(zoneID: zone.id)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await store.setPower(false, lightIDs: store.allLightsZone.lightIDs) }
                    } label: {
                        Label("Everything Off", systemImage: "power")
                    }
                    .accessibilityIdentifier("everything-off")
                }
            }
            .sheet(item: $editingZone) { zone in
                ZoneEditorView(existing: zone)
            }
            .sheet(isPresented: $creatingZone) {
                ZoneEditorView(existing: nil)
            }
        }
    }

    private var addZoneButton: some View {
        Button {
            creatingZone = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("New Zone")
                    .fontWeight(.medium)
                Spacer()
                Text("Mix lights from any system")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .partyGlassCard()
        .accessibilityIdentifier("new-zone")
    }
}
