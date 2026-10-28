import Foundation
import Network

// LAN server for the phone app: GET /status (discovery), GET /feed (needs
// the pairing code). Runs on a fixed port; the menu shows address + code.
@MainActor
final class SyncServer {
    static let port: UInt16 = 48080

    private var listener: NWListener?
    private let store: TranscriptStore
    private let presenceState: () -> String

    // Six digits, generated once per install, shown in the Mac menu.
    let pairingCode: String

    init(store: TranscriptStore, presenceState: @escaping () -> String) {
        self.store = store
        self.presenceState = presenceState
        if let existing = UserDefaults.standard.string(forKey: "syncPairingCode") {
            pairingCode = existing
        } else {
            let code = String(format: "%06d", Int.random(in: 0...999_999))
            UserDefaults.standard.set(code, forKey: "syncPairingCode")
            pairingCode = code
        }
    }

    var address: String {
        "\(Self.localIPAddress() ?? "?"):\(Self.port)"
    }

    func start() {
        guard listener == nil,
              let listener = try? NWListener(using: .tcp,
                                             on: NWEndpoint.Port(rawValue: Self.port)!) else {
            return
        }
        self.listener = listener
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, _, _ in
                Task { @MainActor in
                    self?.handle(connection: connection, raw: data)
                }
            }
        }
        listener.start(queue: .main)
        presenceLog.info("sync server on port \(Self.port)")
    }

    private func handle(connection: NWConnection, raw: Data?) {
        let text = raw.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let responseData: Data
        if let request = SyncHTTP.parse(text) {
            let reply = SyncRouter.route(
                path: request.path, code: request.code, expectedCode: pairingCode,
                statusJSON: { [presenceState] in
                    #"{"app":"jarvis","presence":"\#(presenceState())"}"#
                },
                feedJSON: { [store] in store.feedJSON() })
            responseData = SyncHTTP.response(status: reply.status, json: reply.json)
        } else {
            responseData = SyncHTTP.response(status: 404, json: #"{"error":"bad request"}"#)
        }
        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private static func localIPAddress() -> String? {
        var address: String?
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0 else { return nil }
        defer { freeifaddrs(interfaces) }
        var pointer = interfaces
        while let current = pointer {
            let interface = current.pointee
            let family = interface.ifa_addr.pointee.sa_family
            let name = String(cString: interface.ifa_name)
            if family == UInt8(AF_INET), name == "en0" {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                address = String(cString: host)
            }
            pointer = interface.ifa_next
        }
        return address
    }
}
