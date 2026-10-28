import Foundation

// Pure HTTP plumbing for the phone-sync server — parse, route, respond.
// All unit-tested; the NWListener shell stays logic-free.

enum SyncHTTP {
    struct Request: Equatable {
        let method: String
        let path: String
        let code: String?
    }

    static func parse(_ raw: String) -> Request? {
        let lines = raw.components(separatedBy: "\r\n")
        guard let first = lines.first else { return nil }
        let parts = first.split(separator: " ")
        guard parts.count >= 2, ["GET", "POST"].contains(String(parts[0])) else { return nil }
        let code = lines.dropFirst()
            .first { $0.lowercased().hasPrefix("x-jarvis-code:") }
            .map { $0.dropFirst("x-jarvis-code:".count).trimmingCharacters(in: .whitespaces) }
        return Request(method: String(parts[0]), path: String(parts[1]), code: code)
    }

    static func response(status: Int, json: String) -> Data {
        let name = [200: "OK", 403: "Forbidden", 404: "Not Found"][status] ?? "OK"
        let header = "HTTP/1.1 \(status) \(name)\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(json.utf8.count)\r\n"
            + "Connection: close\r\n\r\n"
        return Data((header + json).utf8)
    }
}

enum SyncRouter {
    struct Reply {
        let status: Int
        let json: String
    }

    // /status is unauthenticated discovery ("is this a Jarvis desk?");
    // everything else needs the pairing code shown in the Mac's menu.
    static func route(path: String, code: String?, expectedCode: String,
                      statusJSON: () -> String, feedJSON: () -> String) -> Reply {
        switch path {
        case "/status":
            return Reply(status: 200, json: statusJSON())
        case "/feed":
            guard code == expectedCode else {
                return Reply(status: 403, json: #"{"error":"bad code"}"#)
            }
            return Reply(status: 200, json: feedJSON())
        default:
            return Reply(status: 404, json: #"{"error":"not found"}"#)
        }
    }
}
