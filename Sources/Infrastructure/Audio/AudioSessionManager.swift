import AVFoundation
import Combine

// MARK: - Audio Session Configuration

/// Audio session mode configuration
public enum AudioSessionMode: Sendable {
    case recording
    case playback
    case conversation
    case inactive

    var category: AVAudioSession.Category {
        switch self {
        case .recording:
            return .record
        case .playback:
            return .playback
        case .conversation:
            return .playAndRecord
        case .inactive:
            return .ambient
        }
    }

    var mode: AVAudioSession.Mode {
        switch self {
        case .recording:
            return .measurement
        case .playback:
            return .default
        case .conversation:
            return .voiceChat
        case .inactive:
            return .default
        }
    }

    var options: AVAudioSession.CategoryOptions {
        switch self {
        case .recording:
            return [.allowBluetooth]
        case .playback:
            return [.mixWithOthers]
        case .conversation:
            return [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        case .inactive:
            return []
        }
    }
}

// MARK: - Audio Route

/// Available audio routes
public struct AudioRoute: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let type: AudioRouteType
    public let isActive: Bool

    public init(id: String, name: String, type: AudioRouteType, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.isActive = isActive
    }
}

public enum AudioRouteType: String, Sendable {
    case builtInSpeaker = "speaker"
    case builtInMicrophone = "microphone"
    case bluetooth = "bluetooth"
    case headphones = "headphones"
    case airPlay = "airplay"
    case carPlay = "carplay"
    case unknown = "unknown"

    init(portType: AVAudioSession.Port) {
        switch portType {
        case .builtInSpeaker:
            self = .builtInSpeaker
        case .builtInMic:
            self = .builtInMicrophone
        case .bluetoothLE, .bluetoothHFP, .bluetoothA2DP:
            self = .bluetooth
        case .headphones, .headsetMic:
            self = .headphones
        case .airPlay:
            self = .airPlay
        case .carAudio:
            self = .carPlay
        default:
            self = .unknown
        }
    }
}

// MARK: - Audio Session Manager Protocol

/// Protocol for audio session management
public protocol AudioSessionManagerProtocol: Sendable {
    var currentMode: AudioSessionMode { get async }
    var isActive: Bool { get async }
    var availableInputs: [AudioRoute] { get async }
    var availableOutputs: [AudioRoute] { get async }

    func configure(for mode: AudioSessionMode) async throws
    func activate() async throws
    func deactivate() async throws
    func setPreferredInput(_ route: AudioRoute) async throws
    func setPreferredOutput(_ route: AudioRoute) async throws
}

// MARK: - Audio Session Manager

/// Manages AVAudioSession for the app
public actor AudioSessionManager: AudioSessionManagerProtocol {
    private let session: AVAudioSession
    private var _currentMode: AudioSessionMode = .inactive
    private var _isActive: Bool = false
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?

    public var currentMode: AudioSessionMode { _currentMode }
    public var isActive: Bool { _isActive }

    public var availableInputs: [AudioRoute] {
        session.availableInputs?.map { port in
            AudioRoute(
                id: port.uid,
                name: port.portName,
                type: AudioRouteType(portType: port.portType),
                isActive: session.currentRoute.inputs.contains { $0.uid == port.uid }
            )
        } ?? []
    }

    public var availableOutputs: [AudioRoute] {
        session.currentRoute.outputs.map { port in
            AudioRoute(
                id: port.uid,
                name: port.portName,
                type: AudioRouteType(portType: port.portType),
                isActive: true
            )
        }
    }

    // Callbacks for interruption handling
    public var onInterruptionBegan: (@Sendable () async -> Void)?
    public var onInterruptionEnded: (@Sendable (Bool) async -> Void)?
    public var onRouteChanged: (@Sendable ([AudioRoute], [AudioRoute]) async -> Void)?

    public init() {
        self.session = AVAudioSession.sharedInstance()
        setupObservers()
    }

    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Configuration

    public func configure(for mode: AudioSessionMode) async throws {
        guard mode != _currentMode else { return }

        do {
            try session.setCategory(
                mode.category,
                mode: mode.mode,
                options: mode.options
            )
            _currentMode = mode
        } catch {
            throw LiveLingoError.audioSessionConfigurationFailed(underlying: error)
        }
    }

    public func activate() async throws {
        guard !_isActive else { return }

        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            _isActive = true
        } catch {
            throw LiveLingoError.audioSessionActivationFailed(underlying: error)
        }
    }

    public func deactivate() async throws {
        guard _isActive else { return }

        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            _isActive = false
        } catch {
            throw LiveLingoError.audioSessionActivationFailed(underlying: error)
        }
    }

    // MARK: - Route Selection

    public func setPreferredInput(_ route: AudioRoute) async throws {
        guard let input = session.availableInputs?.first(where: { $0.uid == route.id }) else {
            throw LiveLingoError.audioInputUnavailable
        }

        do {
            try session.setPreferredInput(input)
        } catch {
            throw LiveLingoError.audioInputUnavailable
        }
    }

    public func setPreferredOutput(_ route: AudioRoute) async throws {
        // Output routing is handled automatically by the system based on category options
        // We can override to speaker using specific API
        if route.type == .builtInSpeaker {
            try session.overrideOutputAudioPort(.speaker)
        } else {
            try session.overrideOutputAudioPort(.none)
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Interruption handling
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            Task { [weak self] in
                await self?.handleInterruption(notification)
            }
        }

        // Route change handling
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            Task { [weak self] in
                await self?.handleRouteChange(notification)
            }
        }
    }

    private func handleInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            _isActive = false
            await onInterruptionBegan?()

        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                let shouldResume = options.contains(.shouldResume)

                if shouldResume {
                    try? await activate()
                }

                await onInterruptionEnded?(shouldResume)
            }

        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) async {
        let inputs = availableInputs
        let outputs = availableOutputs
        await onRouteChanged?(inputs, outputs)
    }
}

// MARK: - Audio Meter

/// Audio level metering for UI visualization
public actor AudioMeter {
    private var levels: [Float] = []
    private let maxSamples: Int

    public init(maxSamples: Int = 50) {
        self.maxSamples = maxSamples
    }

    public func addSample(_ level: Float) {
        levels.append(level)
        if levels.count > maxSamples {
            levels.removeFirst()
        }
    }

    public func getCurrentLevel() -> Float {
        levels.last ?? 0
    }

    public func getAverageLevels(count: Int) -> [Float] {
        let samples = Array(levels.suffix(count))
        if samples.count < count {
            return Array(repeating: 0, count: count - samples.count) + samples
        }
        return samples
    }

    public func reset() {
        levels.removeAll()
    }
}
