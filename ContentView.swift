import SwiftUI

enum MapViewMode: String, CaseIterable {
    case map2D = "2D"
    case map3D = "3D"
}

struct ContentView: View {
    @StateObject private var manager = RoomCaptureManager()
    @State private var status = "Scanning..."
    @State private var mode: MapViewMode = .map2D

    var body: some View {
        ZStack {
            RoomCaptureContainer(manager: manager)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Mode", selection: $mode) {
                            ForEach(MapViewMode.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)

                        if mode == .map2D {
                            MiniMapView(
                                lines: manager.currentFloor.lines,
                                roomSegments: manager.currentFloor.roomSegments,
                                currentPosition: manager.currentPosition2D
                            )
                            .frame(width: 230, height: 230)
                        } else {
                            RoomModelView(surfaces: manager.currentFloor3D.surfaces)
                                .frame(width: 230, height: 230)
                        }
                    }
                    .padding()
                    Spacer()
                }

                Spacer()

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button("Prev Floor") {
                            manager.prevFloor()
                        }
                        .buttonStyle(.bordered)

                        Button("New Floor") {
                            manager.newFloor()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Next Floor") {
                            manager.nextFloor()
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button("Save Map") {
                            do {
                                try MapStorage.shared.save(map: manager.makeSavedMap())
                                status = "Map saved!"
                            } catch {
                                status = "Save failed: \(error.localizedDescription)"
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Load Map") {
                            do {
                                let loaded = try MapStorage.shared.load()
                                manager.applySavedMap(loaded)
                                status = "Map loaded!"
                            } catch {
                                status = "Load failed: \(error.localizedDescription)"
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    HStack(spacing: 12) {
                        Button("Export SVG") {
                            do {
                                let url = try MapExporter.shared.exportSVG(floor: manager.currentFloor)
                                status = "SVG saved: \(url.lastPathComponent)"
                            } catch {
                                status = "SVG export failed: \(error.localizedDescription)"
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Export PDF") {
                            do {
                                let url = try MapExporter.shared.exportPDF(floor: manager.currentFloor)
                                status = "PDF saved: \(url.lastPathComponent)"
                            } catch {
                                status = "PDF export failed: \(error.localizedDescription)"
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Text("Floor \(manager.selectedFloorIndex + 1)")
                        .foregroundColor(.white.opacity(0.85))

                    Text(status)
                        .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            }
        }
    }
}
