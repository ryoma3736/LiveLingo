import Foundation
import AVFoundation

// MARK: - Gemini Audio Streamer

/// Handles audio capture and playback for Gemini Live API
public actor GeminiAudioStreamer {
    // MARK: - Properties

    private var audioEngine: AVAudioEngine?
    private var playbackEngine: AVAudioEngine?
    private var audioPlayer: AVAudioPlayerNode?
    private var audioFormat: AVAudioFormat?

    private var isCapturing = false
    private var isPlaying = false

    private var captureCallback: ((Data) -> Void)?
    private var audioLevelCallback: ((Float) -> Void)?
    private var outputBuffer = Data()

    // Audio format conversion
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat

    // Audio level tracking
    private var lastAudioLevel: Float = 0

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
    public func startCapture(
        onAudioData: @escaping (Data) -> Void,
        onAudioLevel: ((Float) -> Void)? = nil
    ) async throws {
        guard !isCapturing else { return }

        captureCallback = onAudioData
        audioLevelCallback = onAudioLevel

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw LiveLingoError.audioSessionConfigurationFailed(underlying: NSError(domain: "GeminiAudioStreamer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"]))
        }

        let inputNode = audioEngine.inputNode
        let inputNodeFormat = inputNode.outputFormat(forBus: 0)

        print("[AudioStreamer] Input format: \(inputNodeFormat.sampleRate)Hz, \(inputNodeFormat.channelCount) channels")

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
            print("[AudioStreamer] Audio capture started")
        } catch {
            throw LiveLingoError.audioSessionActivationFailed(underlying: error)
        }
    }

    /// Stop capturing audio
    public func stopCapture() async {
        guard isCapturing else { return }

        print("[AudioStreamer] Stopping audio capture...")
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isCapturing = false
        captureCallback = nil
        audioLevelCallback = nil
        print("[AudioStreamer] Audio capture stopped")
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
        print("[AudioStreamer] Stopping playback...")
        audioPlayer?.stop()
        audioPlayer = nil
        playbackEngine?.stop()
        playbackEngine = nil
        isPlaying = false
        outputBuffer = Data()
        print("[AudioStreamer] Playback stopped")
    }

    // MARK: - Private Methods

    private func processInputBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) async {
        guard let callback = captureCallback else { return }

        // Calculate audio level (RMS)
        if let levelCallback = audioLevelCallback {
            let level = calculateRMSLevel(buffer)
            levelCallback(level)
        }

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

    /// Calculate RMS audio level from buffer (0.0 - 1.0)
    private func calculateRMSLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            // For Int16 format, convert and calculate
            if let int16Data = buffer.int16ChannelData {
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    let sample = Float(int16Data[0][i]) / Float(Int16.max)
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(frameLength))
                // Normalize to 0-1 range with some headroom
                return min(rms * 2.0, 1.0)
            }
            return 0
        }

        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameLength {
            let sample = channelData[0][i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frameLength))
        // Normalize to 0-1 range
        return min(rms * 2.0, 1.0)
    }

    private func playBuffer() async throws {
        guard !outputBuffer.isEmpty else { return }

        let dataToPlay = outputBuffer
        outputBuffer = Data()

        print("[AudioStreamer] Playing \(dataToPlay.count) bytes of audio")

        // Create audio buffer from data
        guard let pcmBuffer = dataToBuffer(dataToPlay, format: outputFormat) else {
            print("[AudioStreamer] Failed to create PCM buffer")
            return
        }

        // Setup playback engine if needed (separate from capture engine)
        if audioPlayer == nil {
            print("[AudioStreamer] Setting up playback engine (24kHz)")
            audioPlayer = AVAudioPlayerNode()
            let engine = AVAudioEngine()

            engine.attach(audioPlayer!)
            engine.connect(audioPlayer!, to: engine.mainMixerNode, format: outputFormat)

            do {
                try engine.start()
                print("[AudioStreamer] Playback engine started")
            } catch {
                print("[AudioStreamer] Failed to start playback engine: \(error)")
                throw LiveLingoError.ttsPlaybackFailed(underlying: error)
            }

            self.playbackEngine = engine
        }

        // Schedule buffer for continuous playback
        audioPlayer?.scheduleBuffer(pcmBuffer, completionHandler: nil)

        if !isPlaying {
            audioPlayer?.play()
            isPlaying = true
            print("[AudioStreamer] Started playback")
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

    // Callbacks (nonisolated for access from Sendable closures)
    public nonisolated(unsafe) var onTranscript: (@Sendable (TranscriptItem) -> Void)?
    public nonisolated(unsafe) var onStreamingText: (@Sendable (String) -> Void)?
    public nonisolated(unsafe) var onAudioLevel: (@Sendable (Float) -> Void)?
    public nonisolated(unsafe) var onStateChange: (@Sendable (LiveTranslationState) -> Void)?
    public nonisolated(unsafe) var onError: (@Sendable (Error) -> Void)?

    // Current streaming translation buffer
    private var currentStreamingText: String = ""

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

        // Get API key from configuration or keychain
        let apiKey: String
        let configuredKey = "AIzaSyBG9AiW1hcAPyN0b1PbTLRqAjH-Ri9hZPE" // Gemini API Key
        if !configuredKey.isEmpty && configuredKey != "YOUR_API_KEY_HERE" {
            apiKey = configuredKey
        } else if let keychainKey = try? keychain.loadString(key: .openAIAPIKey) {
            apiKey = keychainKey
        } else {
            throw LiveLingoError.apiKeyMissing(service: "Gemini")
        }

        let config = GeminiLiveConfig(
            apiKey: apiKey,
            model: .gemini25FlashNativeAudio,
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

        // Start audio capture with level monitoring
        try await audioStreamer.startCapture(
            onAudioData: { [weak self] data in
                Task {
                    try? await self?.geminiService.sendAudio(data)
                }
            },
            onAudioLevel: { [weak self] level in
                self?.onAudioLevel?(level)
            }
        )

        isActive = true
        onStateChange?(.active)
        print("[LiveTranslation] Session started")
    }

    /// Stop live translation session
    public func stopSession() async {
        guard isActive else { return }

        print("[LiveTranslation] Stopping session...")
        await audioStreamer.stopCapture()
        await audioStreamer.stopPlayback()
        await geminiService.disconnect()

        isActive = false
        currentStreamingText = ""
        onStateChange?(.inactive)
        print("[LiveTranslation] Session stopped")
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
        // Handle translated text (streaming)
        await geminiService.setOnTranslation { [weak self] text, _ in
            Task { [weak self] in
                guard let self = self else { return }
                await self.appendStreamingText(text)
            }
        }

        // Handle audio output
        await geminiService.setOnAudioOutput { [weak self] data in
            Task {
                try? await self?.audioStreamer.playAudio(data)
            }
        }

        // Handle errors
        await geminiService.setOnError { [weak self] error in
            print("[LiveTranslation] Error: \(error)")
            self?.onError?(error)
        }

        // Handle state changes
        await geminiService.setOnStateChange { [weak self] state in
            Task { [weak self] in
                guard let self = self else { return }
                await self.handleStateChange(state, sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)
            }
        }
    }

    private func appendStreamingText(_ text: String) {
        currentStreamingText += text
        onStreamingText?(currentStreamingText)
    }

    private func handleStateChange(_ state: GeminiLiveState, sourceLanguage: SupportedLanguage, targetLanguage: SupportedLanguage) {
        switch state {
        case .ready:
            // Turn complete - finalize the streaming text
            if !currentStreamingText.isEmpty {
                let item = TranscriptItem(
                    speaker: .speaker1,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    originalText: "", // Gemini Live doesn't provide original
                    translatedText: currentStreamingText
                )
                onTranscript?(item)
                currentStreamingText = ""
            }
            onStateChange?(.active)

        case .listening:
            onStateChange?(.active)

        case .processing, .speaking:
            onStateChange?(.processing)

        case .error(let message):
            onError?(LiveLingoError.sttNotAvailable(reason: message))

        default:
            break
        }
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
