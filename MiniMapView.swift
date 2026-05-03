import SwiftUI

struct MiniMapView: View {
    let lines: [FloorPlanLine]
    let roomSegments: [RoomSegment]
    let currentPosition: SIMD2<Float>

    private let scale: Float = 35.0 // meters -> pixels
    private let gridMeters: Float = 0.5

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let gridSpacing = CGFloat(gridMeters * scale)

            Canvas { context, size in
                func toPoint(_ v: SIMD2<Float>) -> CGPoint {
                    CGPoint(
                        x: CGFloat(v.x * scale) + center.x,
                        y: CGFloat(-v.y * scale) + center.y
                    )
                }

                // Grid
                var gridPath = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    gridPath.move(to: CGPoint(x: x, y: 0))
                    gridPath.addLine(to: CGPoint(x: x, y: size.height))
                    x += gridSpacing
                }
                var y: CGFloat = 0
                while y <= size.height {
                    gridPath.move(to: CGPoint(x: 0, y: y))
                    gridPath.addLine(to: CGPoint(x: size.width, y: y))
                    y += gridSpacing
                }
                context.stroke(gridPath, with: .color(.white.opacity(0.08)), lineWidth: 1)

                // Walls and doors
                for line in lines {
                    var path = Path()
                    path.move(to: toPoint(line.start))
                    path.addLine(to: toPoint(line.end))
                    let color = line.isDoor ? Color.green : Color.white
                    context.stroke(path, with: .color(color), lineWidth: line.isDoor ? 2 : 1)
                }

                // Room paths
                for (index, segment) in roomSegments.enumerated() {
                    guard segment.pathPoints.count > 1 else { continue }
                    var path = Path()
                    path.move(to: toPoint(segment.pathPoints[0]))
                    for p in segment.pathPoints.dropFirst() {
                        path.addLine(to: toPoint(p))
                    }
                    let color = Color(hue: Double(index) * 0.15, saturation: 0.85, brightness: 0.9)
                    context.stroke(path, with: .color(color), lineWidth: 2)
                }

                // Current position
                let pos = toPoint(currentPosition)
                let dot = CGRect(x: pos.x - 4, y: pos.y - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dot), with: .color(.red))
            }
        }
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
    }
}
