import Foundation
import UIKit

final class MapExporter {
    static let shared = MapExporter()
    private init() {}

    func exportSVG(floor: FloorMap) throws -> URL {
        let size: CGFloat = 1000
        let scale: CGFloat = 50
        let center = CGPoint(x: size / 2, y: size / 2)

        func toPoint(_ v: SIMD2<Float>) -> CGPoint {
            CGPoint(
                x: CGFloat(v.x) * scale + center.x,
                y: CGFloat(-v.y) * scale + center.y
            )
        }

        var svg = """
        <svg xmlns="http://www.w3.org/2000/svg" width="\(size)" height="\(size)" viewBox="0 0 \(size) \(size)">
        <rect width="100%" height="100%" fill="black"/>
        """

        for line in floor.lines {
            let a = toPoint(line.start)
            let b = toPoint(line.end)
            let color = line.isDoor ? "lime" : "white"
            svg += "<line x1=\"\(a.x)\" y1=\"\(a.y)\" x2=\"\(b.x)\" y2=\"\(b.y)\" stroke=\"\(color)\" stroke-width=\"2\" />"
        }

        for segment in floor.roomSegments {
            guard segment.pathPoints.count > 1 else { continue }
            let points = segment.pathPoints.map { p in
                let pt = toPoint(p)
                return "\(pt.x),\(pt.y)"
            }.joined(separator: " ")
            svg += "<polyline fill=\"none\" stroke=\"cyan\" stroke-width=\"2\" points=\"\(points)\" />"
        }

        svg += "</svg>"

        let url = documentsURL(filename: "floor_map.svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func exportPDF(floor: FloorMap) throws -> URL {
        let size = CGSize(width: 1000, height: 1000)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        let url = documentsURL(filename: "floor_map.pdf")

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            let cg = context.cgContext

            cg.setFillColor(UIColor.black.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))

            let scale: CGFloat = 50
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            func toPoint(_ v: SIMD2<Float>) -> CGPoint {
                CGPoint(
                    x: CGFloat(v.x) * scale + center.x,
                    y: CGFloat(-v.y) * scale + center.y
                )
            }

            for line in floor.lines {
                let a = toPoint(line.start)
                let b = toPoint(line.end)
                cg.setStrokeColor(line.isDoor ? UIColor.green.cgColor : UIColor.white.cgColor)
                cg.setLineWidth(line.isDoor ? 2 : 1)
                cg.move(to: a)
                cg.addLine(to: b)
                cg.strokePath()
            }

            for segment in floor.roomSegments {
                guard segment.pathPoints.count > 1 else { continue }
                cg.setStrokeColor(UIColor.cyan.cgColor)
                cg.setLineWidth(2)
                cg.beginPath()
                let first = toPoint(segment.pathPoints[0])
                cg.move(to: first)
                for p in segment.pathPoints.dropFirst() {
                    cg.addLine(to: toPoint(p))
                }
                cg.strokePath()
            }
        }

        return url
    }

    private func documentsURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}
