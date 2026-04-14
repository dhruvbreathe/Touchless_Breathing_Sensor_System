//
//  UDPSender.swift
//  FLIROneCameraSwift
//

import Foundation
import Network

final class UDPSender {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "udp.sender")

    init(host: String, port: UInt16) {
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(rawValue: port)!
        self.connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .udp)
        self.connection.start(queue: queue)
    }

    func send(avg: Double, min: Double, max: Double) {
        let payload: [String: Any] = [
            "t": Date().timeIntervalSince1970,
            "avg": avg,
            "min": min,
            "max": max
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        connection.send(content: data, completion: .idempotent)
    }

    deinit {
        connection.cancel()
    }
}
