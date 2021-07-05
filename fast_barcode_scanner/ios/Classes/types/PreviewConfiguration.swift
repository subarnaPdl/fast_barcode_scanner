//
//  PreviewConfiguration.swift
//  fast_barcode_scanner
//
//  Created by Joshua Hoogstraat on 27.06.21.
//

struct PreviewConfiguration {
    let width: Int32
    let height: Int32
    let targetRotation: Int
    let textureId: Int64

    var asDict: [String: Any] {
        ["width": height,
         "height": width,
         "analysis": "\(width)x\(height)",
         "targetRotation": targetRotation,
         "textureId": textureId]
    }
}
