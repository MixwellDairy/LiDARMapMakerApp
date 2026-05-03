import Foundation
import simd

// MARK: - Floor Plan Types

struct FloorPlanLine: Codable {
    var start: SIMD2<Float>
    var end: SIMD2<Float>
    var isDoor: Bool
}

struct RoomSegment: Codable {
    let id: Int
    var pathPoints: [SIMD2<Float>]
}

struct FloorMap: Codable {
    let id: Int
    var lines: [FloorPlanLine]
    var roomSegments: [RoomSegment]
}

// MARK: - 3D Model Types

struct Surface3D {
    let size: SIMD3<Float>
    let isDoor: Bool
    let matrix: simd_float4x4
}

extension Surface3D: Codable {
    enum CodingKeys: String, CodingKey {
        case size, isDoor, matrixValues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        size = try container.decode(SIMD3<Float>.self, forKey: .size)
        isDoor = try container.decode(Bool.self, forKey: .isDoor)
        let v = try container.decode([Float].self, forKey: .matrixValues)
        matrix = simd_float4x4(columns: (
            SIMD4<Float>(v[0], v[1], v[2], v[3]),
            SIMD4<Float>(v[4], v[5], v[6], v[7]),
            SIMD4<Float>(v[8], v[9], v[10], v[11]),
            SIMD4<Float>(v[12], v[13], v[14], v[15])
        ))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(size, forKey: .size)
        try container.encode(isDoor, forKey: .isDoor)
        let c = matrix.columns
        let v: [Float] = [
            c.0.x, c.0.y, c.0.z, c.0.w,
            c.1.x, c.1.y, c.1.z, c.1.w,
            c.2.x, c.2.y, c.2.z, c.2.w,
            c.3.x, c.3.y, c.3.z, c.3.w
        ]
        try container.encode(v, forKey: .matrixValues)
    }
}

struct Floor3DModel: Codable {
    let id: Int
    var surfaces: [Surface3D]
}
