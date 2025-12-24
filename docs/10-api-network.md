# LiveLingo - API・ネットワーク層機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | API・ネットワーク層機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #11 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. モジュール概要

### 2.1 目的

外部API（CoeFont、Google、LLM等）との通信を統一的に管理し、信頼性の高いネットワーク層を提供する。

### 2.2 主要責務

1. HTTPクライアントの統一管理
2. 認証・署名処理
3. リトライ・エラーハンドリング
4. レート制限管理
5. オフライン対応

---

## 3. API一覧

### 3.1 使用API

| API名 | プロバイダー | 用途 | 認証方式 |
|-------|-------------|------|---------|
| CoeFont API | CoeFont | TTS | HMAC-SHA256 |
| Google Cloud Speech | Google | STT | OAuth2 / API Key |
| Google Live Speech | Google | STT (最新) | OAuth2 |
| OpenAI API | OpenAI | 翻訳 | Bearer Token |
| Anthropic API | Anthropic | 翻訳 | API Key |
| Apple Translation | Apple | 翻訳 | N/A (オンデバイス) |

### 3.2 エンドポイント一覧

| エンドポイント | メソッド | 用途 |
|---------------|---------|------|
| `https://api.coefont.cloud/v2/text2speech` | POST | 音声合成 |
| `https://api.coefont.cloud/v2/coefonts/pro` | GET | 音声一覧 |
| `https://speech.googleapis.com/v1/speech:recognize` | POST | 音声認識 |
| `https://api.openai.com/v1/chat/completions` | POST | 翻訳 |
| `https://api.anthropic.com/v1/messages` | POST | 翻訳 |

---

## 4. 技術設計

### 4.1 アーキテクチャ

```
┌─────────────────────────────────────────────────────────────┐
│                    Network Layer                             │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────┐       │
│  │              NetworkManager                       │       │
│  │  - リクエスト/レスポンス管理                      │       │
│  │  - エラーハンドリング                             │       │
│  │  - オフライン検出                                 │       │
│  └──────────────────────────────────────────────────┘       │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Auth        │  │ Rate        │  │ Retry       │         │
│  │ Manager     │  │ Limiter     │  │ Handler     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                          │                                   │
│                          ▼                                   │
│  ┌──────────────────────────────────────────────────┐       │
│  │                 API Clients                       │       │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐│       │
│  │  │CoeFont  │ │ Google  │ │ OpenAI  │ │Anthropic││       │
│  │  │ Client  │ │ Client  │ │ Client  │ │ Client  ││       │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘│       │
│  └──────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 共通プロトコル

```swift
import Foundation
import Combine

// MARK: - API Client Protocol

protocol APIClientProtocol {
    associatedtype RequestType: APIRequest
    associatedtype ResponseType: Decodable

    func execute(_ request: RequestType) async throws -> ResponseType
}

// MARK: - API Request Protocol

protocol APIRequest {
    var endpoint: URL { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: Data? { get }
    var timeout: TimeInterval { get }
}

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH
}

// MARK: - API Response

struct APIResponse<T: Decodable> {
    let data: T
    let statusCode: Int
    let headers: [String: String]
    let responseTime: TimeInterval
}

// MARK: - Network Manager

final class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let retryHandler: RetryHandler
    private let rateLimiter: RateLimiter
    private let reachability: NetworkReachability

    @Published private(set) var isOnline: Bool = true

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true

        self.session = URLSession(configuration: config)
        self.retryHandler = RetryHandler()
        self.rateLimiter = RateLimiter()
        self.reachability = NetworkReachability()

        setupReachabilityMonitoring()
    }

    // MARK: - リクエスト実行

    func execute<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        // オフラインチェック
        guard isOnline else {
            throw NetworkError.offline
        }

        // レート制限チェック
        try await rateLimiter.checkLimit(for: request.url!)

        let startTime = CFAbsoluteTimeGetCurrent()

        // リトライ付きリクエスト
        let (data, response) = try await retryHandler.execute {
            try await self.session.data(for: request)
        }

        let endTime = CFAbsoluteTimeGetCurrent()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // レスポンス処理
        try validateResponse(httpResponse, data: data)

        let decoded = try JSONDecoder().decode(T.self, from: data)

        return APIResponse(
            data: decoded,
            statusCode: httpResponse.statusCode,
            headers: httpResponse.allHeaderFields as? [String: String] ?? [:],
            responseTime: endTime - startTime
        )
    }

    // MARK: - Validation

    private func validateResponse(_ response: HTTPURLResponse, data: Data) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 429:
            throw NetworkError.rateLimited
        case 500...599:
            throw NetworkError.serverError(statusCode: response.statusCode)
        default:
            throw NetworkError.unknown(statusCode: response.statusCode, data: data)
        }
    }

    // MARK: - Reachability

    private func setupReachabilityMonitoring() {
        reachability.startMonitoring { [weak self] status in
            self?.isOnline = status == .connected
        }
    }
}
```

---

## 5. CoeFont API クライアント

### 5.1 実装

```swift
import Foundation
import CryptoKit

// MARK: - CoeFont API Client

final class CoeFontAPIClient {
    private let accessKey: String
    private let clientSecret: String
    private let baseURL = URL(string: "https://api.coefont.cloud/v2/")!
    private let networkManager = NetworkManager.shared

    // MARK: - 初期化

    init(accessKey: String, clientSecret: String) {
        self.accessKey = accessKey
        self.clientSecret = clientSecret
    }

    // MARK: - HMAC-SHA256署名生成

    private func generateSignature(timestamp: String, body: String) -> String {
        let message = timestamp + body
        let key = SymmetricKey(data: Data(clientSecret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8),
            using: key
        )
        return signature.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - 音声合成

    func synthesize(
        text: String,
        coefontID: String,
        speed: Float = 1.0,
        pitch: Float = 0.0
    ) async throws -> Data {
        let timestamp = String(Int(Date().timeIntervalSince1970))

        let requestBody: [String: Any] = [
            "coefont": coefontID,
            "text": text,
            "speed": speed,
            "pitch": pitch
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        let bodyString = String(data: bodyData, encoding: .utf8)!
        let signature = generateSignature(timestamp: timestamp, body: bodyString)

        var request = URLRequest(url: baseURL.appendingPathComponent("text2speech"))
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessKey, forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Date")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Content")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CoeFontError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            throw CoeFontError.authenticationFailed
        case 429:
            throw CoeFontError.rateLimitExceeded
        case 400:
            throw CoeFontError.invalidRequest(parseError(from: data))
        default:
            throw CoeFontError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - 利用可能音声の取得

    func getAvailableVoices() async throws -> [CoeFontVoice] {
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let signature = generateSignature(timestamp: timestamp, body: "")

        var request = URLRequest(url: baseURL.appendingPathComponent("coefonts/pro"))
        request.httpMethod = "GET"
        request.setValue(accessKey, forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "X-Coefont-Date")
        request.setValue(signature, forHTTPHeaderField: "X-Coefont-Content")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode([CoeFontVoice].self, from: data)
    }

    private func parseError(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = json["message"] as? String {
            return message
        }
        return "Unknown error"
    }
}

// MARK: - CoeFont Voice Model

struct CoeFontVoice: Codable, Identifiable {
    let id: String
    let name: String
    let language: String
    let gender: String
    let description: String?
    let sampleURL: URL?

    enum CodingKeys: String, CodingKey {
        case id = "coefont"
        case name
        case language = "lang"
        case gender
        case description
        case sampleURL = "sample_url"
    }
}

// MARK: - CoeFont Error

enum CoeFontError: Error, LocalizedError {
    case authenticationFailed
    case rateLimitExceeded
    case invalidRequest(String)
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "CoeFont API認証に失敗しました"
        case .rateLimitExceeded:
            return "APIレート制限を超過しました"
        case .invalidRequest(let message):
            return "リクエストエラー: \(message)"
        case .invalidResponse:
            return "無効なレスポンス"
        case .serverError(let code):
            return "サーバーエラー: \(code)"
        }
    }
}
```

---

## 6. Google Speech API クライアント

### 6.1 Google Live Speech API

```swift
import Foundation

// MARK: - Google Speech Client

final class GoogleSpeechClient {
    private let apiKey: String
    private let baseURL = URL(string: "https://speech.googleapis.com/v1/")!

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - 同期認識

    func recognize(
        audioData: Data,
        languageCode: String,
        sampleRateHertz: Int = 16000
    ) async throws -> SpeechRecognitionResponse {
        let requestBody = SpeechRecognitionRequest(
            config: RecognitionConfig(
                encoding: "LINEAR16",
                sampleRateHertz: sampleRateHertz,
                languageCode: languageCode,
                enableAutomaticPunctuation: true
            ),
            audio: RecognitionAudio(
                content: audioData.base64EncodedString()
            )
        )

        var request = URLRequest(url: baseURL.appendingPathComponent("speech:recognize"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleSpeechError.requestFailed
        }

        return try JSONDecoder().decode(SpeechRecognitionResponse.self, from: data)
    }

    // MARK: - ストリーミング認識

    func streamingRecognize(
        audioStream: AsyncStream<Data>,
        languageCode: String
    ) -> AsyncThrowingStream<StreamingRecognitionResult, Error> {
        AsyncThrowingStream { continuation in
            Task {
                // WebSocket接続を確立
                // ストリーミング認識を実行
                // 結果を逐次yield

                continuation.finish()
            }
        }
    }
}

// MARK: - Request/Response Models

struct SpeechRecognitionRequest: Codable {
    let config: RecognitionConfig
    let audio: RecognitionAudio
}

struct RecognitionConfig: Codable {
    let encoding: String
    let sampleRateHertz: Int
    let languageCode: String
    let enableAutomaticPunctuation: Bool
}

struct RecognitionAudio: Codable {
    let content: String
}

struct SpeechRecognitionResponse: Codable {
    let results: [RecognitionResult]?
}

struct RecognitionResult: Codable {
    let alternatives: [SpeechAlternative]
}

struct SpeechAlternative: Codable {
    let transcript: String
    let confidence: Float?
}

struct StreamingRecognitionResult {
    let transcript: String
    let isFinal: Bool
    let confidence: Float
}

enum GoogleSpeechError: Error {
    case requestFailed
    case streamingError
    case invalidResponse
}
```

---

## 7. LLM翻訳APIクライアント

### 7.1 OpenAI / Anthropic

```swift
import Foundation

// MARK: - LLM API Client

final class LLMAPIClient {
    enum Provider {
        case openAI
        case anthropic
    }

    private let provider: Provider
    private let apiKey: String

    init(provider: Provider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
    }

    // MARK: - 翻訳リクエスト

    func translate(
        text: String,
        from sourceLanguage: String,
        to targetLanguage: String,
        context: [ConversationTurn]? = nil
    ) async throws -> String {
        let prompt = buildTranslationPrompt(
            text: text,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            context: context
        )

        switch provider {
        case .openAI:
            return try await callOpenAI(prompt: prompt)
        case .anthropic:
            return try await callAnthropic(prompt: prompt)
        }
    }

    // MARK: - OpenAI

    private func callOpenAI(prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!

        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": "You are a professional interpreter."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000,
            "temperature": 0.3
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        return response.choices.first?.message.content ?? ""
    }

    // MARK: - Anthropic

    private func callAnthropic(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!

        let requestBody: [String: Any] = [
            "model": "claude-3-haiku-20240307",
            "max_tokens": 1000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        return response.content.first?.text ?? ""
    }

    // MARK: - プロンプト構築

    private func buildTranslationPrompt(
        text: String,
        sourceLanguage: String,
        targetLanguage: String,
        context: [ConversationTurn]?
    ) -> String {
        var prompt = """
        Translate the following text from \(sourceLanguage) to \(targetLanguage).
        Return ONLY the translation, without any explanation.

        """

        if let context = context, !context.isEmpty {
            prompt += "Context from previous conversation:\n"
            for turn in context.suffix(5) {
                prompt += "- \(turn.originalText) → \(turn.translatedText)\n"
            }
            prompt += "\n"
        }

        prompt += "Text to translate: \(text)"

        return prompt
    }
}

// MARK: - Response Models

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

struct OpenAIMessage: Codable {
    let content: String
}

struct AnthropicResponse: Codable {
    let content: [AnthropicContent]
}

struct AnthropicContent: Codable {
    let text: String
}
```

---

## 8. リトライ・エラーハンドリング

### 8.1 リトライハンドラー

```swift
// MARK: - Retry Handler

final class RetryHandler {
    struct Configuration {
        let maxRetries: Int
        let baseDelay: TimeInterval
        let maxDelay: TimeInterval
        let retryableStatusCodes: Set<Int>
    }

    private let config: Configuration

    init(config: Configuration = .default) {
        self.config = config
    }

    func execute<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = config.baseDelay

        for attempt in 0..<config.maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error

                // リトライ可能かチェック
                guard shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }

                // 指数バックオフ
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay = min(delay * 2, config.maxDelay)
            }
        }

        throw lastError ?? NetworkError.unknown(statusCode: 0, data: Data())
    }

    private func shouldRetry(error: Error, attempt: Int) -> Bool {
        if attempt >= config.maxRetries - 1 {
            return false
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .serverError, .rateLimited:
                return true
            default:
                return false
            }
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        return false
    }
}

extension RetryHandler.Configuration {
    static let `default` = RetryHandler.Configuration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 10.0,
        retryableStatusCodes: [429, 500, 502, 503, 504]
    )
}
```

### 8.2 レート制限管理

```swift
// MARK: - Rate Limiter

final class RateLimiter {
    private var requestCounts: [String: [Date]] = [:]
    private let lock = NSLock()

    struct Limit {
        let requests: Int
        let window: TimeInterval
    }

    private let limits: [String: Limit] = [
        "api.coefont.cloud": Limit(requests: 100, window: 60),
        "api.openai.com": Limit(requests: 60, window: 60),
        "api.anthropic.com": Limit(requests: 60, window: 60)
    ]

    func checkLimit(for url: URL) async throws {
        guard let host = url.host else { return }

        lock.lock()
        defer { lock.unlock() }

        let now = Date()

        // 古いリクエストを削除
        if var requests = requestCounts[host] {
            let limit = limits[host] ?? Limit(requests: 100, window: 60)
            requests = requests.filter { now.timeIntervalSince($0) < limit.window }
            requestCounts[host] = requests

            // レート制限チェック
            if requests.count >= limit.requests {
                let oldestRequest = requests.first!
                let waitTime = limit.window - now.timeIntervalSince(oldestRequest)

                if waitTime > 0 {
                    throw NetworkError.rateLimited
                }
            }
        }

        // リクエストを記録
        requestCounts[host, default: []].append(now)
    }
}
```

---

## 9. ネットワークエラー定義

```swift
// MARK: - Network Error

enum NetworkError: Error, LocalizedError {
    case offline
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case invalidResponse
    case serverError(statusCode: Int)
    case timeout
    case unknown(statusCode: Int, data: Data)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "インターネット接続がありません"
        case .unauthorized:
            return "認証に失敗しました"
        case .forbidden:
            return "アクセスが拒否されました"
        case .notFound:
            return "リソースが見つかりません"
        case .rateLimited:
            return "リクエスト制限を超過しました。しばらくお待ちください"
        case .invalidResponse:
            return "無効なレスポンスを受信しました"
        case .serverError(let code):
            return "サーバーエラーが発生しました (\(code))"
        case .timeout:
            return "接続がタイムアウトしました"
        case .unknown(let code, _):
            return "不明なエラーが発生しました (\(code))"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .serverError, .rateLimited, .timeout:
            return true
        default:
            return false
        }
    }
}
```

---

## 10. テスト仕様

### 10.1 Mock API Client

```swift
final class MockNetworkManager: NetworkManagerProtocol {
    var mockResponses: [String: Result<Data, Error>] = [:]
    var requestHistory: [URLRequest] = []

    func execute<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type
    ) async throws -> APIResponse<T> {
        requestHistory.append(request)

        let key = request.url?.absoluteString ?? ""

        guard let result = mockResponses[key] else {
            throw NetworkError.notFound
        }

        switch result {
        case .success(let data):
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return APIResponse(
                data: decoded,
                statusCode: 200,
                headers: [:],
                responseTime: 0.1
            )
        case .failure(let error):
            throw error
        }
    }
}
```

---

## 11. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
