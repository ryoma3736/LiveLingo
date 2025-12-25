import AVFoundation
import Speech
import UserNotifications
#if os(iOS)
import UIKit
#endif

// MARK: - Permission Manager Protocol

/// Protocol for permission management
public protocol PermissionManagerProtocol: Sendable {
    func checkStatus(for permission: Permission) async -> PermissionStatus
    func request(_ permission: Permission) async -> PermissionStatus
    func requestAll(_ permissions: [Permission]) async -> [Permission: PermissionStatus]
    func openSettings() async
}

// MARK: - Permission Manager

/// Manages system permissions for the app
public actor PermissionManager: PermissionManagerProtocol {
    public static let shared = PermissionManager()

    public init() {}

    // MARK: - Check Status

    public func checkStatus(for permission: Permission) async -> PermissionStatus {
        switch permission {
        case .microphone:
            return checkMicrophoneStatus()
        case .speechRecognition:
            return await checkSpeechRecognitionStatus()
        case .notifications:
            return await checkNotificationStatus()
        }
    }

    private func checkMicrophoneStatus() -> PermissionStatus {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            return .notDetermined
        case .granted:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .restricted
        }
    }

    private func checkSpeechRecognitionStatus() async -> PermissionStatus {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            return .notDetermined
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    private func checkNotificationStatus() async -> PermissionStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        @unknown default:
            return .restricted
        }
    }

    // MARK: - Request Permission

    public func request(_ permission: Permission) async -> PermissionStatus {
        switch permission {
        case .microphone:
            return await requestMicrophonePermission()
        case .speechRecognition:
            return await requestSpeechRecognitionPermission()
        case .notifications:
            return await requestNotificationPermission()
        }
    }

    private func requestMicrophonePermission() async -> PermissionStatus {
        let granted = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return granted ? .authorized : .denied
    }

    private func requestSpeechRecognitionPermission() async -> PermissionStatus {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: .authorized)
                case .denied:
                    continuation.resume(returning: .denied)
                case .restricted:
                    continuation.resume(returning: .restricted)
                case .notDetermined:
                    continuation.resume(returning: .notDetermined)
                @unknown default:
                    continuation.resume(returning: .restricted)
                }
            }
        }
    }

    private func requestNotificationPermission() async -> PermissionStatus {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    // MARK: - Request All

    public func requestAll(_ permissions: [Permission]) async -> [Permission: PermissionStatus] {
        var results: [Permission: PermissionStatus] = [:]

        for permission in permissions {
            let currentStatus = await checkStatus(for: permission)

            if currentStatus == .notDetermined {
                results[permission] = await request(permission)
            } else {
                results[permission] = currentStatus
            }
        }

        return results
    }

    // MARK: - Settings

    public func openSettings() async {
        #if os(iOS)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            await MainActor.run {
                UIApplication.shared.open(settingsURL)
            }
        }
        #endif
    }
}

// MARK: - Permission Requirement

/// Represents a permission requirement with context
public struct PermissionRequirement: Sendable {
    public let permission: Permission
    public let title: String
    public let description: String
    public let isRequired: Bool

    public init(permission: Permission, title: String, description: String, isRequired: Bool = true) {
        self.permission = permission
        self.title = title
        self.description = description
        self.isRequired = isRequired
    }

    public static let allRequired: [PermissionRequirement] = [
        PermissionRequirement(
            permission: .microphone,
            title: "Microphone Access",
            description: "Required to capture your speech for real-time translation.",
            isRequired: true
        ),
        PermissionRequirement(
            permission: .speechRecognition,
            title: "Speech Recognition",
            description: "Required to convert your speech into text for translation.",
            isRequired: true
        ),
        PermissionRequirement(
            permission: .notifications,
            title: "Notifications",
            description: "Optional. Receive alerts when translations are ready in the background.",
            isRequired: false
        )
    ]
}

// MARK: - Permission Check Result

/// Result of checking all required permissions
public struct PermissionCheckResult: Sendable {
    public let statuses: [Permission: PermissionStatus]

    public var allGranted: Bool {
        statuses.allSatisfy { $0.value == .authorized }
    }

    public var requiredGranted: Bool {
        let required: [Permission] = [.microphone, .speechRecognition]
        return required.allSatisfy { permission in
            statuses[permission] == .authorized
        }
    }

    public var deniedPermissions: [Permission] {
        statuses.filter { $0.value == .denied }.map { $0.key }
    }

    public var notDeterminedPermissions: [Permission] {
        statuses.filter { $0.value == .notDetermined }.map { $0.key }
    }

    public init(statuses: [Permission: PermissionStatus]) {
        self.statuses = statuses
    }
}
