import Foundation

enum APIError: LocalizedError {
    case notConfigured
    case unauthorized
    case server(String)
    case decoding(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Set your server address first."
        case .unauthorized: return "Your session expired. Please sign in again."
        case .server(let message): return message
        case .decoding(let message): return "Unexpected server response (\(message))."
        case .network(let message): return message
        }
    }
}

/// Thin client over the GymCoach web API. Authentication is the same
/// `gymcoach-session` cookie the website uses; URLSession keeps it in the
/// shared cookie storage so it survives app restarts.
final class APIClient {
    static let shared = APIClient()

    var baseURL: URL?
    /// Called once on a 401. Return true when a silent re-login succeeded.
    var reauthenticate: (() async -> Bool)?

    private let session: URLSession
    let decoder: JSONDecoder

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let d = APIClient.isoFractional.date(from: raw) ?? APIClient.isoPlain.date(from: raw) {
                return d
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date \(raw)")
        }
    }

    private func makeRequest(_ method: String, _ path: String, json: [String: Any]?) throws -> URLRequest {
        guard let base = baseURL else { throw APIError.notConfigured }
        let root = base.absoluteString.hasSuffix("/") ? String(base.absoluteString.dropLast()) : base.absoluteString
        guard let url = URL(string: root + path) else { throw APIError.notConfigured }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return request
    }

    private func errorMessage(from data: Data, status: Int) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = obj["error"] as? String {
            return message
        }
        return "Server error (\(status))."
    }

    @discardableResult
    func raw(_ method: String, _ path: String, json: [String: Any]? = nil, retry: Bool = true, attempt: Int = 0) async throws -> Data {
        let request = try makeRequest(method, path, json: json)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network("No response.") }
        if http.statusCode == 401 {
            if retry, let reauthenticate, await reauthenticate() {
                return try await raw(method, path, json: json, retry: false, attempt: attempt)
            }
            throw APIError.unauthorized
        }
        // The hosted backend can shed load (502/503/504) when many requests land
        // at once. Reads are safe to repeat, so back off and try again.
        if [502, 503, 504].contains(http.statusCode), method == "GET", attempt < 3 {
            try? await Task.sleep(for: .milliseconds(350 * (attempt + 1) * (attempt + 1)))
            return try await raw(method, path, json: json, retry: retry, attempt: attempt + 1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.server(errorMessage(from: data, status: http.statusCode))
        }
        return data
    }

    func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws -> T {
        try decode(try await raw("GET", path))
    }

    func send<T: Decodable>(_ method: String, _ path: String, json: [String: Any]? = nil, as type: T.Type = T.self) async throws -> T {
        try decode(try await raw(method, path, json: json))
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Streams a plain-text response (the coach chat) and reports the
    /// conversation id from the response header.
    func stream(_ path: String, json: [String: Any],
                onHeaders: @escaping (String?) -> Void,
                onText: @escaping (String) -> Void) async throws {
        let request = try makeRequest("POST", path, json: json)
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: request)
        } catch {
            throw APIError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.network("No response.") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            var body = Data()
            for try await b in bytes { body.append(b) }
            throw APIError.server(errorMessage(from: body, status: http.statusCode))
        }
        onHeaders(http.value(forHTTPHeaderField: "X-Conversation-Id"))
        var buffer = Data()
        for try await byte in bytes {
            buffer.append(byte)
            // Only emit once the buffer ends on a complete UTF-8 sequence.
            if let text = String(data: buffer, encoding: .utf8) {
                onText(text)
                buffer.removeAll(keepingCapacity: true)
            }
        }
    }
}
