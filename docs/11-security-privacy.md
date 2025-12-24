# LiveLingo - セキュリティ・プライバシー機能要件定義書

## 1. ドキュメント情報

| 項目 | 内容 |
|------|------|
| ドキュメント名 | セキュリティ・プライバシー機能要件定義書 |
| バージョン | 1.0.0 |
| 作成日 | 2024-12-24 |
| 関連Issue | Sub-Issue #12 |
| 親ドキュメント | [01-overview.md](./01-overview.md) |

---

## 2. セキュリティ要件概要

### 2.1 セキュリティ目標

1. **機密性**: ユーザーの音声・テキストデータの保護
2. **完全性**: データの改ざん防止
3. **可用性**: サービスの継続的提供
4. **認証**: ユーザー・APIの正当性確認

### 2.2 コンプライアンス要件

| 規制 | 対象地域 | 対応状況 |
|------|---------|---------|
| GDPR | EU | 対応必須 |
| 個人情報保護法 | 日本 | 対応必須 |
| CCPA | カリフォルニア州 | 対応必須 |
| HIPAA | 米国（医療） | 将来対応 |

---

## 3. データ保護

### 3.1 データ分類

| データ種別 | 機密レベル | 保存場所 | 暗号化 |
|-----------|-----------|---------|--------|
| 音声データ（処理中） | 高 | メモリ | - |
| 音声データ（保存） | 高 | ローカル/なし | AES-256 |
| 翻訳テキスト | 中 | ローカル | AES-256 |
| 会話履歴 | 中 | SwiftData | AES-256 |
| ユーザー設定 | 低 | UserDefaults | - |
| APIキー | 最高 | Keychain | - |

### 3.2 暗号化実装

```swift
import CryptoKit
import Security

// MARK: - Encryption Manager

final class EncryptionManager {
    private let keychain = KeychainManager.shared

    // MARK: - AES-256-GCM暗号化

    func encrypt(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.seal(data, using: key)

        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }

        return combined
    }

    func decrypt(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        return try AES.GCM.open(sealedBox, using: key)
    }

    // MARK: - キー管理

    private func getOrCreateEncryptionKey() throws -> SymmetricKey {
        let keyTag = "com.livelingo.encryption.key"

        // Keychainから取得を試みる
        if let keyData = try? keychain.getData(forKey: keyTag) {
            return SymmetricKey(data: keyData)
        }

        // 新規キー生成
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try keychain.save(data: keyData, forKey: keyTag)

        return key
    }
}

enum EncryptionError: Error {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
}
```

### 3.3 Keychainマネージャー

```swift
// MARK: - Keychain Manager

final class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    // MARK: - データ保存

    func save(data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // 既存のアイテムを削除
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func save(string: String, forKey key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }
        try save(data: data, forKey: key)
    }

    // MARK: - データ取得

    func getData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.readFailed(status)
        }

        return result as? Data
    }

    func getString(forKey key: String) throws -> String? {
        guard let data = try getData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - データ削除

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case encodingFailed
}
```

---

## 4. 認証・認可

### 4.1 Sign in with Apple

```swift
import AuthenticationServices

// MARK: - Apple Sign In Manager

final class AppleSignInManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var userID: String?
    @Published var email: String?

    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.email, .fullName]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func checkAuthenticationState() {
        guard let userID = KeychainManager.shared.try? getString(forKey: "appleUserID") else {
            isAuthenticated = false
            return
        }

        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, _ in
            DispatchQueue.main.async {
                self.isAuthenticated = state == .authorized
            }
        }
    }

    func signOut() {
        try? KeychainManager.shared.delete(forKey: "appleUserID")
        isAuthenticated = false
        userID = nil
        email = nil
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return
        }

        let userID = credential.user
        try? KeychainManager.shared.save(string: userID, forKey: "appleUserID")

        DispatchQueue.main.async {
            self.userID = userID
            self.email = credential.email
            self.isAuthenticated = true
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        print("Sign in with Apple failed: \(error)")
    }
}

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }!
    }
}
```

### 4.2 生体認証

```swift
import LocalAuthentication

// MARK: - Biometric Authentication Manager

final class BiometricAuthManager: ObservableObject {
    @Published var isBiometricAvailable = false
    @Published var biometricType: LABiometryType = .none

    private let context = LAContext()

    init() {
        checkBiometricAvailability()
    }

    func checkBiometricAvailability() {
        var error: NSError?
        isBiometricAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = NSLocalizedString("cancel", comment: "")

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            throw BiometricError.from(laError: error)
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case failed
    case unknown

    static func from(laError: LAError) -> BiometricError {
        switch laError.code {
        case .biometryNotAvailable:
            return .notAvailable
        case .biometryNotEnrolled:
            return .notEnrolled
        case .biometryLockout:
            return .lockout
        case .userCancel, .systemCancel, .appCancel:
            return .cancelled
        case .authenticationFailed:
            return .failed
        default:
            return .unknown
        }
    }

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "生体認証は利用できません"
        case .notEnrolled:
            return "生体認証が設定されていません"
        case .lockout:
            return "認証がロックされました"
        case .cancelled:
            return "認証がキャンセルされました"
        case .failed:
            return "認証に失敗しました"
        case .unknown:
            return "認証エラーが発生しました"
        }
    }
}
```

---

## 5. 通信セキュリティ

### 5.1 TLS設定

```swift
// MARK: - Secure URL Session

final class SecureNetworkManager {
    static let shared = SecureNetworkManager()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default

        // TLS 1.3を要求
        config.tlsMinimumSupportedProtocolVersion = .TLSv13

        // 証明書ピンニング用のデリゲート設定
        self.session = URLSession(
            configuration: config,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
    }

    func request(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

// MARK: - Certificate Pinning

final class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    // 信頼する証明書のハッシュ
    private let pinnedHashes: [String: Set<String>] = [
        "api.coefont.cloud": [
            "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
        ],
        "api.openai.com": [
            "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="
        ]
    ]

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String? else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 証明書の検証
        if validateCertificate(serverTrust: serverTrust, host: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validateCertificate(serverTrust: SecTrust, host: String) -> Bool {
        // 証明書チェーンの取得
        guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
            return false
        }

        // 各証明書のハッシュをチェック
        for certificate in certificateChain {
            let data = SecCertificateCopyData(certificate) as Data
            let hash = SHA256.hash(data: data)
            let hashString = "sha256/" + Data(hash).base64EncodedString()

            if let expectedHashes = pinnedHashes[host],
               expectedHashes.contains(hashString) {
                return true
            }
        }

        return false
    }
}
```

---

## 6. プライバシー管理

### 6.1 プライバシー設定

```swift
// MARK: - Privacy Settings

struct PrivacySettings: Codable {
    var saveConversationHistory: Bool = true
    var sendAnalytics: Bool = false
    var sendCrashReports: Bool = true
    var shareDataForImprovement: Bool = false
    var autoDeleteHistoryDays: Int? = nil  // nil = 削除しない

    static let `default` = PrivacySettings()
}

// MARK: - Privacy Manager

final class PrivacyManager: ObservableObject {
    @Published var settings: PrivacySettings

    private let storage: UserDefaults

    init(storage: UserDefaults = .standard) {
        self.storage = storage

        if let data = storage.data(forKey: "privacy_settings"),
           let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) {
            self.settings = settings
        } else {
            self.settings = .default
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            storage.set(data, forKey: "privacy_settings")
        }
    }

    // MARK: - データ削除

    func deleteAllData() async throws {
        // 会話履歴削除
        try await ConversationRepository.shared.deleteAll()

        // キャッシュ削除
        TranslationCache.shared.clearAll()

        // Keychain（認証情報以外）削除
        try KeychainManager.shared.delete(forKey: "encryption_key")

        // UserDefaults削除
        if let bundleID = Bundle.main.bundleIdentifier {
            storage.removePersistentDomain(forName: bundleID)
        }
    }

    func deleteOldHistory() async throws {
        guard let days = settings.autoDeleteHistoryDays else { return }

        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        try await ConversationRepository.shared.deleteBefore(date: cutoffDate)
    }
}
```

### 6.2 データ収集の最小化

```swift
// MARK: - Data Minimization

struct DataMinimizationPolicy {
    // 音声データは処理後すぐに破棄
    static let audioRetentionSeconds: TimeInterval = 0

    // 翻訳ログは設定に応じて保存
    static func shouldSaveTranscript(settings: PrivacySettings) -> Bool {
        settings.saveConversationHistory
    }

    // 分析データの匿名化
    static func anonymize(data: AnalyticsEvent) -> AnalyticsEvent {
        var anonymized = data
        anonymized.userID = nil
        anonymized.ipAddress = nil
        anonymized.deviceID = hashDeviceID(data.deviceID)
        return anonymized
    }

    private static func hashDeviceID(_ id: String?) -> String? {
        guard let id = id else { return nil }
        let hash = SHA256.hash(data: Data(id.utf8))
        return hash.map { String(format: "%02x", $0) }.joined().prefix(16).description
    }
}
```

---

## 7. 権限管理

### 7.1 必要な権限

| 権限 | 必須 | 用途 | Info.plist Key |
|------|-----|------|---------------|
| マイク | Yes | 音声入力 | NSMicrophoneUsageDescription |
| 音声認識 | Yes | STT | NSSpeechRecognitionUsageDescription |
| Face ID/Touch ID | No | 生体認証 | NSFaceIDUsageDescription |
| 位置情報 | No | 言語自動設定 | NSLocationWhenInUseUsageDescription |

### 7.2 権限チェック・リクエスト

```swift
// MARK: - Permission Manager

final class PermissionManager: ObservableObject {
    @Published var microphoneStatus: AVAudioSession.RecordPermission = .undetermined
    @Published var speechRecognitionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    func checkAllPermissions() {
        microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        speechRecognitionStatus = SFSpeechRecognizer.authorizationStatus()
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    self.microphoneStatus = granted ? .granted : .denied
                }
                continuation.resume(returning: granted)
            }
        }
    }

    func requestSpeechRecognitionPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechRecognitionStatus = status
                }
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    var allPermissionsGranted: Bool {
        microphoneStatus == .granted && speechRecognitionStatus == .authorized
    }
}
```

---

## 8. セキュリティUI

### 8.1 プライバシー設定画面

```swift
struct PrivacySettingsView: View {
    @EnvironmentObject var privacyManager: PrivacyManager
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section {
                Toggle(isOn: $privacyManager.settings.saveConversationHistory) {
                    Label {
                        Text("privacy_save_history")
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }

                if privacyManager.settings.saveConversationHistory {
                    Picker("privacy_auto_delete", selection: autoDeleteBinding) {
                        Text("privacy_never").tag(nil as Int?)
                        Text("privacy_7days").tag(7 as Int?)
                        Text("privacy_30days").tag(30 as Int?)
                        Text("privacy_90days").tag(90 as Int?)
                    }
                }
            } header: {
                Text("privacy_history_section")
            }

            Section {
                Toggle(isOn: $privacyManager.settings.sendCrashReports) {
                    Label {
                        Text("privacy_crash_reports")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }

                Toggle(isOn: $privacyManager.settings.sendAnalytics) {
                    Label {
                        Text("privacy_analytics")
                    } icon: {
                        Image(systemName: "chart.bar")
                    }
                }

                Toggle(isOn: $privacyManager.settings.shareDataForImprovement) {
                    Label {
                        Text("privacy_improvement")
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                }
            } header: {
                Text("privacy_data_collection")
            } footer: {
                Text("privacy_data_collection_footer")
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label {
                        Text("privacy_delete_all")
                    } icon: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .navigationTitle("privacy_settings")
        .onChange(of: privacyManager.settings) { _ in
            privacyManager.save()
        }
        .alert("privacy_delete_confirm_title", isPresented: $showDeleteConfirmation) {
            Button("cancel", role: .cancel) {}
            Button("delete", role: .destructive) {
                Task {
                    try? await privacyManager.deleteAllData()
                }
            }
        } message: {
            Text("privacy_delete_confirm_message")
        }
    }

    private var autoDeleteBinding: Binding<Int?> {
        Binding(
            get: { privacyManager.settings.autoDeleteHistoryDays },
            set: { privacyManager.settings.autoDeleteHistoryDays = $0 }
        )
    }
}
```

---

## 9. 監査・ログ

### 9.1 セキュリティログ

```swift
// MARK: - Security Logger

final class SecurityLogger {
    static let shared = SecurityLogger()

    enum EventType: String {
        case authSuccess = "AUTH_SUCCESS"
        case authFailure = "AUTH_FAILURE"
        case dataAccess = "DATA_ACCESS"
        case dataDelete = "DATA_DELETE"
        case permissionChange = "PERMISSION_CHANGE"
        case encryptionError = "ENCRYPTION_ERROR"
    }

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func log(event: EventType, details: [String: Any] = [:]) {
        var logEntry: [String: Any] = [
            "timestamp": dateFormatter.string(from: Date()),
            "event": event.rawValue
        ]

        // 機密情報を除外
        let safeDetails = details.filter { key, _ in
            !["password", "apiKey", "token", "secret"].contains(key.lowercased())
        }

        logEntry["details"] = safeDetails

        #if DEBUG
        print("🔒 Security Log: \(logEntry)")
        #endif

        // 本番環境ではセキュアなログサービスに送信
        // sendToSecureLogService(logEntry)
    }
}
```

---

## 10. テスト仕様

### 10.1 セキュリティテスト

```swift
final class SecurityTests: XCTestCase {
    func test_keychainStorage_shouldSecurelyStoreData() throws {
        // Given
        let keychain = KeychainManager.shared
        let testData = "sensitive_api_key"

        // When
        try keychain.save(string: testData, forKey: "test_key")
        let retrieved = try keychain.getString(forKey: "test_key")

        // Then
        XCTAssertEqual(retrieved, testData)

        // Cleanup
        try keychain.delete(forKey: "test_key")
    }

    func test_encryption_shouldEncryptAndDecryptData() throws {
        // Given
        let encryptionManager = EncryptionManager()
        let originalData = "Hello, World!".data(using: .utf8)!

        // When
        let encrypted = try encryptionManager.encrypt(originalData)
        let decrypted = try encryptionManager.decrypt(encrypted)

        // Then
        XCTAssertNotEqual(encrypted, originalData)
        XCTAssertEqual(decrypted, originalData)
    }

    func test_certificatePinning_shouldRejectInvalidCertificate() {
        // Certificate pinning validation test
    }
}
```

---

## 11. 変更履歴

| バージョン | 日付 | 変更内容 | 担当 |
|-----------|------|---------|------|
| 1.0.0 | 2024-12-24 | 初版作成 | AI Agent |
