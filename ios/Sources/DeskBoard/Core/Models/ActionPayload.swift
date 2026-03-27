import Foundation

nonisolated enum ActionPayload: Codable, Hashable, Sendable {
    case none
    case url(String)
    case text(String)
    case keyCombo(modifiers: [String], key: String)
    case httpRequest(HTTPRequestConfig)
    case webSocketMessage(WebSocketConfig)
    case sequence([ButtonAction])
    case shortcutName(String)

    struct HTTPRequestConfig: Codable, Hashable, Sendable {
        var url: String
        var method: HTTPMethod = .get
        var headers: [String: String] = [:]
        var body: String?
        var timeoutSeconds: Double = 10

        enum HTTPMethod: String, Codable, Sendable, CaseIterable {
            case get = "GET"
            case post = "POST"
            case put = "PUT"
            case delete = "DELETE"
            case patch = "PATCH"
        }
    }

    struct WebSocketConfig: Codable, Hashable, Sendable {
        var url: String
        var message: String
        var expectResponse: Bool = false
        var timeoutSeconds: Double = 5
    }
}
