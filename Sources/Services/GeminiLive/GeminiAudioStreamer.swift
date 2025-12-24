import Foundation
import AVFoundation

// MARK: - Gemini Audio Streamer

/// Handles audio capture and playback for Gemini Live API
public actor GeminiAudioStreamer {
    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    private var isCapturing = false
    private var isPlaying = false

    private var captureCallback: ((Data) -> Void)?
    private var outputBuffer = Data()

    // Audio format conversion
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat

    // MARK: - Initialization

    public init() {
        // Input format: 16-bit PCM, 16kHz, mono (Gemini requirement)
        inputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: GeminiAudioFormat.inputSampleRate,
            channels: AVAudioChannelCount(GeminiAudioFormat.inputChannels),
            interleaved: true
        )!

        // Output format: 24kHz (Gemini output)
        outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: GeminiAudioFormat.outputSampleRate,
            channels: 1,
            interleaved: true
        )!
    }

    // MARK: - Audio Capture

    /// Start capturing audio from microphone
    public func startCapture(onAudioData: @escaping (Data) -> Void) async throws {
        guard !isCapturing else { return }

        captureCallback = onAudioData

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw LiveLingoError.audioSessionConfigurationFailed(reason: "Failed to create audio engine")
        }

        let inputNode = audioEngine.inputNode
        let inputNodeFormat = inputNode.outputFormat(forBus: 0)

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(GeminiAudioFormat.chunkSize), format: inputNodeFormat) { [weak self] buffer, _ in
            Task {
                await self?.processInputBuffer(buffer, inputFormat: inputNodeFormat)
            }
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isCapturing = true
        } catch {
            throw LiveLingoError.audioSessionActivationFailed(reason: error.localizedDescription)
        }
    }

    /// Stop capturing audio
    public func stopCapture() async {
        guard isCapturing else { return }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false
        captureCallback = nil
    }

    // MARK: - Audio Playback

    /// Play audio data received from Gemini
    public func playAudio(_ data: Data) async throws {
        // Accumulate data
        outputBuffer.append(data)

        // Play when we have enough data
        if outputBuffer.count >= GeminiAudioFormat.chunkSize * 4 {
            try await playBuffer()
        }
    }

    /// Flush and play remaining audio
    public func flushAudio() async throws {
        if !outputBuffer.isEmpty {
            try await playBuffer()
        }
    }

    /// Stop audio playback
    public func stopPlayback() async {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        outputBuffer = Data()
    }

    // MARK: - Private Methods

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) async {
        guard let callback = captureCallback else { return }

        // Convert to 16kHz mono PCM if needed
        let convertedData: Data

        if inputFormat.sampleRate == GeminiAudioFormat.inputSampleRate &&
           inputFormat.channelCount == 1 {
            // Already in correct format
            convertedData = bufferToData(buffer)
        } else {
            // Need to convert
            if let converted = convertBuffer(buffer, from: inputFormat, to: self.inputFormat) {
                convertedData = bufferToData(converted)
            } else {
                return
            }
        }

        callback(convertedData)
    }

    private func playBuffer() async throws {
        guard !outputBuffer.isEmpty else { return }

        let dataToPlay = outputBuffer
        outputBuffer = Data()

        // Create audio buffer from data
        guard let pcmBuffer = dataToBuffer(dataToPlay, format: outputFormat) else {
            return
        }

        // Setup player if needed
        if audioPlayer == nil {
            audioPlayer = AVAudioPlayerNode()
            let engine = AVAudioEngine()

            engine.attach(audioPlayer!)
            engine.connect(audioPlayer!, to: engine.mainMixerNode, format: outputFormat)

            do {
                try engine.start()
            } catch {
                throw LiveLingoError.ttsPlaybackFailed(reason: error.localizedDescription)
            }

            self.audioEngine = engine
        }

        // Schedule and play buffer
        audioPlayer?.scheduleBuffer(pcmBuffer) {
            // Buffer finished playing
        }

        if !isPlaying {
            audioPlayer?.play()
            isPlaying = true
        }
    }

    // MARK: - Format Conversion Helpers

    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }

    private func dataToBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(data.count) / format.streamDescription.pointee.mBytesPerFrame

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBufferPointer in
            let audioBuffer = buffer.audioBufferList.pointee.mBuffers
            memcpy(audioBuffer.mData, rawBufferPointer.baseAddress, data.count)
        }

        return buffer
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, from sourceFormat: AVAudioFormat, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            return nil
        }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCapacity) else {
            return nil
        }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil {
            return nil
        }

        return outputBuffer
    }
}

// MARK: - Unified Live Translation Service

/// High-level service combining Gemini Live API with audio handling
public actor LiveTranslationService {
    private let geminiService: GeminiLiveService
    private let audioStreamer: GeminiAudioStreamer
    private let keychain: KeychainManagerProtocol

    private var isActive = false

    // Callbacks
    public var onTranscript: (@Sendable (TranscriptItem) -> Void)?
    public var onStateChange: (@Sendable (LiveTranslationState) -> Void)?
    public var onError: (@Sendable (Error) -> Void)?

    public init(keychain: KeychainManagerProtocol = KeychainManager.shared) {
        self.geminiService = GeminiLiveService()
        self.audioStreamer = GeminiAudioStreamer()
        self.keychain = keychain
    }

    // MARK: - Public API

    /// Start live translation session
    public func startSession(
        sourceLanguage: SupportedLanguage,
        targetLanguage: SupportedLanguage,
        bidirectional: Bool = true
    ) async throws {
        guard !isActive else {
            throw LiveLingoError.sttAlreadyRecognizing
        }

        // Get API key from keychain
        guard let apiKey = try? keychain.loadString(key: .openAIAPIKey) else {
            // For Gemini, we might use a different key - this is placeholder
            throw LiveLingoError.authenticationRequired
        }

        let config = GeminiLiveConfig(
            apiKey: apiKey,
            model: .gemini2FlashLive,
            responseModalities: [.audio, .text]
        )

        let translationMode = TranslationMode(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            bidirectional: bidirectional
        )

        // Setup callbacks
        await setupCallbacks(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)

        // Connect to Gemini
        try await geminiService.connect(config: config, translationMode: translationMode)

        // Start audio capture
        try await audioStreamer.startCapture { [weak self] data in
            Task {
                try? await self?.geminiService.sendAudio(data)
            }
        }

        isActive = true
        onStateChange?(.active)
    }

    /// Stop live translation session
    public func stopSession() async {
        guard isActive else { return }

        await audioStreamer.stopCapture()
        await audioStreamer.stopPlayback()
        await geminiService.disconnect()

        isActive = false
        onStateChange?(.inactive)
    }

    /// Send text message for translation
    public func sendText(_ text: String) async throws {
        guard isActive else {
            throw LiveLingoError.sttNotAvailable(reason: "Session not active")
        }

        try await geminiService.sendText(text)
    }

    // MARK: - Private Methods

    private func setupCallbacks(sourceLanguage: SupportedLanguage, targetLanguage: SupportedLanguage) async {
        // Handle translated text
        await geminiService.setOnTranslation { [weak self] text, language in
            let item = TranscriptItem(
                speaker: .speaker1,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage,
                originalText: "", // We don't have the original in real-time mode
                translatedText: text
            )
            self?.onTranscript?(item)
        }

        // Handle audio output
        await geminiService.setOnAudioOutput { [weak self] data in
            Task {
                try? await self?.audioStreamer.playAudio(data)
            }
        }

        // Handle errors
        await geminiService.setOnError { [weak self] error in
            self?.onError?(error)
        }

        // Handle state changes
        await geminiService.setOnStateChange { [weak self] state in
            switch state {
            case .ready, .listening:
                self?.onStateChange?(.active)
            case .processing, .speaking:
                self?.onStateChange?(.processing)
            case .error(let message):
                self?.onError?(LiveLingoError.sttNotAvailable(reason: message))
            default:
                break
            }
        }
    }
}

// MARK: - Callback Setters for GeminiLiveService

extension GeminiLiveService {
    func setOnTranslation(_ callback: (@Sendable (String, SupportedLanguage) -> Void)?) async {
        self.onTranslation = callback
    }

    func setOnAudioOutput(_ callback: (@Sendable (Data) -> Void)?) async {
        self.onAudioOutput = callback
    }

    func setOnError(_ callback: (@Sendable (Error) -> Void)?) async {
        self.onError = callback
    }

    func setOnStateChange(_ callback: (@Sendable (GeminiLiveState) -> Void)?) async {
        self.onStateChange = callback
    }
}

// MARK: - Live Translation State

public enum LiveTranslationState: Sendable {
    case inactive
    case connecting
    case active
    case processing
    case error
}
