// TrackerClient.swift
import Foundation
import Network
import CoreGraphics

final class TrackerClient: ObservableObject {
    static let shared = TrackerClient()

    @Published var fingertipPosition: CGPoint = .zero
    @Published var isPenDown: Bool = false
    
    @Published var leftHandPosition: CGPoint? = nil
    @Published var leftHandPinchDistance: CGFloat? = nil

    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "TrackerClientQueue")

    private init() {
        startConnection()
    }

    private func startConnection() {
        let host = NWEndpoint.Host("127.0.0.1")
        let port = NWEndpoint.Port(rawValue: 65432)!
        connection = NWConnection(host: host, port: port, using: .tcp)

        connection?.stateUpdateHandler = { state in
            if case .ready = state {
                self.receiveData()
            }
        }
        connection?.start(queue: queue)
    }

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, _, _ in
            guard let data = data,
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                self.receiveData()
                return
            }

            DispatchQueue.main.async {
                if let down = dict["down"] as? Bool {
                    self.isPenDown = down
                    if down, let x = dict["x"] as? Double, let y = dict["y"] as? Double {
                        self.fingertipPosition = CGPoint(x: x, y: y)
                    }
                }
                
                if let lx = dict["lx"] as? Double, let ly = dict["ly"] as? Double {
                    self.leftHandPosition = CGPoint(x: lx, y: ly)
                } else {
                    self.leftHandPosition = nil
                }

                if let lpinch = dict["lpinch"] as? Double {
                    self.leftHandPinchDistance = CGFloat(lpinch)
                } else {
                    self.leftHandPinchDistance = nil
                }
            }
            self.receiveData()
        }
    }
}

