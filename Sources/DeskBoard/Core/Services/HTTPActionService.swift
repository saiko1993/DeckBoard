import Foundation

final class HTTPActionService: @unchecked Sendable {

    static let shared = HTTPActionService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    struct Response: Sendable {
        let statusCode: Int
        let body: Data
        let headers: [String: String]
    }

    func execute(config: ActionPayload.HTTPRequestConfig) async throws -> Response {
        guard let url = URL(string: config.url) else {
            throw ActionError.invalidURL(config.url)
        }

        var request = URLRequest(url: url, timeoutInterval: config.timeoutSeconds)
        request.httpMethod = config.method.rawValue

        for (key, value) in config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = config.body, !body.isEmpty {
            request.httpBody = Data(body.utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActionError.invalidResponse
        }

        var responseHeaders: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let k = key as? String, let v = value as? String {
                responseHeaders[k] = v
            }
        }

        return Response(
            statusCode: httpResponse.statusCode,
            body: data,
            headers: responseHeaders
        )
    }

    func testConnection(urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        var request = URLRequest(url: url, timeoutInterval: 5)
        request.httpMethod = "HEAD"
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200...499).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}

enum ActionError: Error, LocalizedError, Sendable {
    case invalidURL(String)
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case timeout
    case connectionRefused
    case networkUnavailable
    case unsupportedAction(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid response from server"
        case .httpError(let code, let body): return "HTTP \(code)\(body.map { ": \($0)" } ?? "")"
        case .timeout: return "Request timed out"
        case .connectionRefused: return "Connection refused"
        case .networkUnavailable: return "Network unavailable"
        case .unsupportedAction(let type): return "Unsupported action: \(type)"
        }
    }
}
