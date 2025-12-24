import Foundation

// MARK: - Network Configuration

/// Network request configuration
public struct NetworkConfiguration: Sendable {
    public let baseURL: URL
    public let timeoutInterval: TimeInterval
    public let maxRetries: Int
    public let retryDelay: TimeInterval

    public static var `default`: NetworkConfiguration {
        NetworkConfiguration(
            baseURL: URL(string: "https://api.livelingo.app")!,
            timeoutInterval: 30,
            maxRetries: 3,
            retryDelay: 1.0
        )
    }

    public init(baseURL: URL, timeoutInterval: TimeInterval = 30, maxRetries: Int = 3, retryDelay: TimeInterval = 1.0) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay
    }
}

// MARK: - HTTP Method

/// HTTP methods
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

// MARK: - Network Request

/// Network request definition
public struct NetworkRequest: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]
    public let queryItems: [URLQueryItem]?
    public let body: Data?

    public init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }

    public static func get(_ path: String, queryItems: [URLQueryItem]? = nil) -> NetworkRequest {
        NetworkRequest(path: path, method: .get, queryItems: queryItems)
    }

    public static func post(_ path: String, body: Data?) -> NetworkRequest {
        NetworkRequest(path: path, method: .post, body: body)
    }

    public static func post<T: Encodable>(_ path: String, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> NetworkRequest {
        let data = try encoder.encode(body)
        return NetworkRequest(path: path, method: .post, headers: ["Content-Type": "application/json"], body: data)
    }
}

// MARK: - Network Response

/// Network response wrapper
public struct NetworkResponse<T: Sendable>: Sendable {
    public let data: T
    public let statusCode: Int
    public let headers: [AnyHashable: Any]

    public init(data: T, statusCode: Int, headers: [AnyHashable: Any] = [:]) {
        self.data = data
        self.statusCode = statusCode
        self.headers = headers
    }
}

// MARK: - Network Client Protocol

/// Protocol for network client
public protocol NetworkClientProtocol: Sendable {
    func send(_ request: NetworkRequest) async throws -> NetworkResponse<Data>
    func send<T: Decodable & Sendable>(_ request: NetworkRequest, decoder: JSONDecoder) async throws -> NetworkResponse<T>
    func stream(_ request: NetworkRequest) -> AsyncThrowingStream<Data, Error>
}

// MARK: - Network Client Implementation

/// Main network client using URLSession
public actor NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let configuration: NetworkConfiguration
    private let authProvider: AuthenticationProviderProtocol?

    public init(
        configuration: NetworkConfiguration = .default,
        authProvider: AuthenticationProviderProtocol? = nil
    ) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeoutInterval
        sessionConfig.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": "LiveLingo/1.0"
        ]

        self.session = URLSession(configuration: sessionConfig)
        self.configuration = configuration
        self.authProvider = authProvider
    }

    public func send(_ request: NetworkRequest) async throws -> NetworkResponse<Data> {
        let urlRequest = try await buildURLRequest(request)

        var lastError: Error?

        for attempt in 0..<configuration.maxRetries {
            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw LiveLingoError.networkInvalidResponse
                }

                try validateResponse(httpResponse, data: data)

                return NetworkResponse(
                    data: data,
                    statusCode: httpResponse.statusCode,
                    headers: httpResponse.allHeaderFields
                )
            } catch {
                lastError = error

                if !isRetryable(error) {
                    throw error
                }

                if attempt < configuration.maxRetries - 1 {
                    let delay = configuration.retryDelay * Double(attempt + 1)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? LiveLingoError.networkUnavailable
    }

    public func send<T: Decodable & Sendable>(_ request: NetworkRequest, decoder: JSONDecoder = JSONDecoder()) async throws -> NetworkResponse<T> {
        let response = try await send(request)

        do {
            let decoded = try decoder.decode(T.self, from: response.data)
            return NetworkResponse(
                data: decoded,
                statusCode: response.statusCode,
                headers: response.headers
            )
        } catch {
            throw LiveLingoError.networkDecodingFailed(type: String(describing: T.self))
        }
    }

    public func stream(_ request: NetworkRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let urlRequest = try await buildURLRequest(request)
                    let (bytes, response) = try await session.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: LiveLingoError.networkInvalidResponse)
                        return
                    }

                    guard (200..<300).contains(httpResponse.statusCode) else {
                        continuation.finish(throwing: LiveLingoError.networkRequestFailed(
                            statusCode: httpResponse.statusCode,
                            message: "Stream request failed"
                        ))
                        return
                    }

                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)

                        // Yield data chunks on newlines (for SSE/NDJSON)
                        if byte == UInt8(ascii: "\n") {
                            continuation.yield(buffer)
                            buffer = Data()
                        }
                    }

                    if !buffer.isEmpty {
                        continuation.yield(buffer)
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func buildURLRequest(_ request: NetworkRequest) async throws -> URLRequest {
        var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: true)!
        components.path = request.path
        components.queryItems = request.queryItems

        guard let url = components.url else {
            throw LiveLingoError.networkInvalidURL(url: request.path)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body

        // Add default headers
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        // Add authentication if available
        if let authProvider = authProvider {
            let token = try await authProvider.getAccessToken()
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return urlRequest
    }

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401:
            throw LiveLingoError.authenticationRequired
        case 403:
            throw LiveLingoError.authorizationFailed(reason: "Access forbidden")
        case 429:
            throw LiveLingoError.networkRateLimited(retryAfter: extractRetryAfter(from: response))
        case 400..<500:
            let message = String(data: data, encoding: .utf8) ?? "Client error"
            throw LiveLingoError.networkRequestFailed(statusCode: response.statusCode, message: message)
        case 500..<600:
            let message = String(data: data, encoding: .utf8) ?? "Server error"
            throw LiveLingoError.networkRequestFailed(statusCode: response.statusCode, message: message)
        default:
            throw LiveLingoError.networkRequestFailed(statusCode: response.statusCode, message: "Unknown error")
        }
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        if let lingoError = error as? LiveLingoError {
            switch lingoError {
            case .networkRateLimited, .networkUnavailable:
                return true
            default:
                return false
            }
        }

        return false
    }

    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(retryAfter) {
            return seconds
        }
        return nil
    }
}

// MARK: - Authentication Provider Protocol

/// Protocol for authentication providers
public protocol AuthenticationProviderProtocol: Sendable {
    func getAccessToken() async throws -> String
    func refreshToken() async throws -> String
    func clearCredentials() async
}
