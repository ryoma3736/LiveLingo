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
    /// Optimized for low-latency: starts playback after 2048 bytes (~42ms at 24kHz)
    public func playAudio(_ data: Data) async throws {
        // Accumulate data
        outputBuffer.append(data)

        // Play when we have enough data
        // Reduced from 4x to 2x chunk size for lower latency (85ms → 42ms)
        // 2048 bytes at 24kHz 16-bit mono = ~42ms
        if outputBuffer.count >= GeminiAudioFormat.chunkSize * 2 {
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

        // Create audio buffer from Gemini data (24kHz mono)
        guard let sourceBuffer = dataToBuffer(dataToPlay, format: outputFormat) else {
            print("[AudioStreamer] Failed to create PCM buffer")
            return
        }

        // Setup playback engine if needed (separate from capture engine)
        if audioPlayer == nil {
            print("[AudioStreamer] Setting up playback engine")
            audioPlayer = AVAudioPlayerNode()
            let engine = AVAudioEngine()

            engine.attach(audioPlayer!)

            // Get mixer format (device native format - usually 44.1kHz or 48kHz stereo)
            let mixerFormat = engine.mainMixerNode.outputFormat(forBus: 0)
            print("[AudioStreamer] Mixer format: \(mixerFormat.sampleRate)Hz, \(mixerFormat.channelCount) channels")
            print("[AudioStreamer] Source format: \(outputFormat.sampleRate)Hz, \(outputFormat.channelCount) channels")

            // Connect player to mixer with mixer's format (not source format)
            // This tells the player what format to output
            engine.connect(audioPlayer!, to: engine.mainMixerNode, format: mixerFormat)

            do {
                try engine.start()
                print("[AudioStreamer] Playback engine started")
            } catch {
                print("[AudioStreamer] Failed to start playback engine: \(error)")
                throw LiveLingoError.ttsPlaybackFailed(underlying: error)
            }

            self.playbackEngine = engine
        }

        // Convert source buffer (24kHz mono) to mixer format (e.g., 48kHz stereo)
        guard let mixerFormat = playbackEngine?.mainMixerNode.outputFormat(forBus: 0),
              let convertedBuffer = convertBufferForPlayback(sourceBuffer, to: mixerFormat) else {
            print("[AudioStreamer] Failed to convert buffer for playback")
            return
        }

        // Schedule converted buffer for playback
        audioPlayer?.scheduleBuffer(convertedBuffer, completionHandler: nil)

        if !isPlaying {
            audioPlayer?.play()
            isPlaying = true
            print("[AudioStreamer] Started playback")
        }
    }

    /// Convert audio buffer from source format to target format for playback
    /// Handles: Int16 mono 24kHz → Float32 stereo 48kHz (typical iOS device format)
    private func convertBufferForPlayback(_ sourceBuffer: AVAudioPCMBuffer, to targetFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        print("[AudioStreamer] Converting from \(sourceBuffer.format) to \(targetFormat)")

        // If formats match exactly, no conversion needed
        if sourceBuffer.format.sampleRate == targetFormat.sampleRate &&
           sourceBuffer.format.channelCount == targetFormat.channelCount &&
           sourceBuffer.format.commonFormat == targetFormat.commonFormat {
            return sourceBuffer
        }

        // Step 1: Create intermediate Float32 mono format for cleaner conversion
        guard let float32MonoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sourceBuffer.format.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            print("[AudioStreamer] Failed to create intermediate format")
            return nil
        }

        // Step 2: Convert Int16 mono → Float32 mono
        guard let float32Converter = AVAudioConverter(from: sourceBuffer.format, to: float32MonoFormat) else {
            print("[AudioStreamer] Failed to create Int16→Float32 converter")
            return nil
        }

        guard let float32Buffer = AVAudioPCMBuffer(pcmFormat: float32MonoFormat, frameCapacity: sourceBuffer.frameLength) else {
            print("[AudioStreamer] Failed to create float32 buffer")
            return nil
        }

        var error1: NSError?
        var inputConsumed1 = false
        let status1 = float32Converter.convert(to: float32Buffer, error: &error1) { _, outStatus in
            if inputConsumed1 {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed1 = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if status1 == .error || error1 != nil {
            print("[AudioStreamer] Int16→Float32 conversion failed: \(error1?.localizedDescription ?? "unknown")")
            return nil
        }

        print("[AudioStreamer] Step 1: Int16→Float32 done, frames: \(float32Buffer.frameLength)")

        // Step 3: Convert Float32 mono → Target format (Float32 stereo at device sample rate)
        guard let finalConverter = AVAudioConverter(from: float32MonoFormat, to: targetFormat) else {
            print("[AudioStreamer] Failed to create Float32→Target converter")
            return nil
        }

        // Calculate output frame count based on sample rate ratio
        let sampleRateRatio = targetFormat.sampleRate / float32MonoFormat.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(float32Buffer.frameLength) * sampleRateRatio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputFrameCount) else {
            print("[AudioStreamer] Failed to create output buffer")
            return nil
        }

        var error2: NSError?
        var inputConsumed2 = false
        let status2 = finalConverter.convert(to: outputBuffer, error: &error2) { _, outStatus in
            if inputConsumed2 {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed2 = true
            outStatus.pointee = .haveData
            return float32Buffer
        }

        if status2 == .error || error2 != nil {
            print("[AudioStreamer] Float32→Target conversion failed: \(error2?.localizedDescription ?? "unknown")")
            return nil
        }

        print("[AudioStreamer] Step 2: Float32→Target done, frames: \(outputBuffer.frameLength)")
        print("[AudioStreamer] Final conversion: \(sourceBuffer.frameLength) frames → \(outputBuffer.frameLength) frames")
        return outputBuffer
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
    private let audioSessionManager: AudioSessionManager
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

    // Text finalization timeout (3 seconds of silence = finalize)
    private var textFinalizationTask: Task<Void, Never>?
    private let textFinalizationTimeout: UInt64 = 3_000_000_000 // 3 seconds in nanoseconds

    public init(keychain: KeychainManagerProtocol = KeychainManager.shared) {
        self.geminiService = GeminiLiveService()
        self.audioStreamer = GeminiAudioStreamer()
        self.audioSessionManager = AudioSessionManager()
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

        // Get API key from Keychain (secure storage)
        let apiKey: String
        if let keychainKey = try? keychain.loadString(key: .geminiAPIKey), !keychainKey.isEmpty {
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

        // IMPORTANT: Configure audio session for simultaneous capture and playback
        // This is required for continuous conversation mode
        print("[LiveTranslation] Configuring audio session for conversation mode...")
        try await audioSessionManager.configure(for: .conversation)
        try await audioSessionManager.activate()
        print("[LiveTranslation] Audio session configured: .playAndRecord with .voiceChat mode")

        // Setup callbacks
        await setupCallbacks(sourceLanguage: sourceLanguage, targetLanguage: targetLanguage)

        // Connect to Gemini
        try await geminiService.connect(config: config, translationMode: translationMode)

        // Start audio capture with level monitoring
        try await audioStreamer.startCapture(
            onAudioData: { [weak self] data in
                Task {
                    do {
                        try await self?.geminiService.sendAudio(data)
                    } catch {
                        // Log errors instead of silently ignoring
                        print("[LiveTranslation] Audio send error: \(error.localizedDescription)")
                        // Notify error callback for severe errors
                        if case LiveLingoError.geminiNotConnected = error {
                            self?.onError?(error)
                        }
                    }
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

        // Cancel text finalization task
        textFinalizationTask?.cancel()
        textFinalizationTask = nil

        await audioStreamer.stopCapture()
        await audioStreamer.stopPlayback()
        await geminiService.disconnect()

        // Deactivate audio session
        do {
            try await audioSessionManager.deactivate()
            print("[LiveTranslation] Audio session deactivated")
        } catch {
            print("[LiveTranslation] Failed to deactivate audio session: \(error)")
        }

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
            print("[LiveTranslation] Received audio from Gemini: \(data.count) bytes")
            Task {
                do {
                    try await self?.audioStreamer.playAudio(data)
                    print("[LiveTranslation] Audio queued for playback")
                } catch {
                    print("[LiveTranslation] Audio playback error: \(error)")
                }
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

        // Schedule timeout-based finalization
        // If no new text arrives for 3 seconds, finalize the current text
        scheduleTextFinalization()
    }

    /// Schedule a timeout to finalize streaming text after silence period
    private func scheduleTextFinalization() {
        // Cancel any existing finalization task
        textFinalizationTask?.cancel()

        // Capture timeout value before Task to avoid actor isolation issues
        let timeout = textFinalizationTimeout

        textFinalizationTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeout)

                // If we get here, 3 seconds passed without new text
                guard let self = self else { return }

                // Check and finalize within actor context
                await self.checkAndFinalizeText()
            } catch {
                // Task was cancelled - new text arrived, which is fine
            }
        }
    }

    /// Check if text needs finalization and finalize if so (actor-isolated)
    private func checkAndFinalizeText() async {
        guard !currentStreamingText.isEmpty else { return }

        print("[LiveTranslation] Auto-finalizing text after 3s silence: \(currentStreamingText.prefix(50))...")

        // Create transcript item (we don't have language info here, so use defaults)
        // The actual finalization with proper language info happens in handleStateChange
        // This is a fallback for bidirectional mode where turnComplete might not fire

        // Just mark it as finalized by clearing after notifying
        // The UI will have already shown the text via onStreamingText
        await forceTextFinalization()
    }

    /// Force finalize the current streaming text (timeout fallback)
    private func forceTextFinalization() async {
        guard !currentStreamingText.isEmpty else { return }

        // Flush any remaining audio
        do {
            try await audioStreamer.flushAudio()
        } catch {
            print("[LiveTranslation] Failed to flush audio on force finalization: \(error)")
        }

        // Clear the text buffer (UI already has the text via onStreamingText)
        currentStreamingText = ""
        print("[LiveTranslation] Text buffer cleared after force finalization")
    }

    private func handleStateChange(_ state: GeminiLiveState, sourceLanguage: SupportedLanguage, targetLanguage: SupportedLanguage) {
        switch state {
        case .ready:
            // Initial ready state after setup
            print("[LiveTranslation] Ready state - session initialized")
            onStateChange?(.active)

        case .listening:
            // Listening state - either initial or after turn complete
            // Cancel timeout-based finalization since turnComplete fired
            textFinalizationTask?.cancel()
            textFinalizationTask = nil

            // Finalize any streaming text if present (turn complete scenario)
            if !currentStreamingText.isEmpty {
                print("[LiveTranslation] Finalizing streaming text: \(currentStreamingText.prefix(50))...")
                let item = TranscriptItem(
                    speaker: .speaker1,
                    sourceLanguage: sourceLanguage,
                    targetLanguage: targetLanguage,
                    originalText: "", // Gemini Live doesn't provide original
                    translatedText: currentStreamingText
                )
                onTranscript?(item)
                currentStreamingText = ""

                // Flush any remaining audio in the buffer
                Task { [weak self] in
                    do {
                        try await self?.audioStreamer.flushAudio()
                        print("[LiveTranslation] Audio buffer flushed")
                    } catch {
                        print("[LiveTranslation] Failed to flush audio: \(error)")
                    }
                }
            }
            print("[LiveTranslation] Listening for input - continuous conversation active")
            onStateChange?(.active)

        case .processing, .speaking:
            onStateChange?(.processing)

        case .error(let message):
            print("[LiveTranslation] Error state: \(message)")
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
