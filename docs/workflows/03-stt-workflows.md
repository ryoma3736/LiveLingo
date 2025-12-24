# LiveLingo - Speech Recognition (STT) Workflows

## WF-STT-001: Initialize SFSpeechRecognizer

Setup speech recognition with permission verification.

```mermaid
sequenceDiagram
    participant App as Application
    participant Perm as PermissionManager
    participant STT as SpeechRecognitionManager
    participant SF as SFSpeechRecognizer
    participant Engine as AVAudioEngine

    App->>Perm: checkSpeechRecognitionPermission()

    alt Not Determined
        Perm->>SF: requestAuthorization()
        SF-->>Perm: authorizationStatus
    end

    alt Authorized
        App->>STT: initialize(locale: ja-JP)
        STT->>SF: SFSpeechRecognizer(locale:)

        alt Recognizer Available
            SF-->>STT: recognizer (isAvailable: true)
            STT->>Engine: AVAudioEngine()
            Engine->>Engine: prepare()
            STT-->>App: initialized successfully
        else Recognizer Unavailable
            SF-->>STT: recognizer (isAvailable: false)
            STT->>STT: fallbackToWhisperKit()
            STT-->>App: using offline fallback
        end
    else Denied
        Perm-->>App: permissionDenied
        App->>App: showPermissionRequiredAlert()
    end
```

---

## WF-STT-002: Real-time Recognition

Continuous speech to text conversion.

```mermaid
sequenceDiagram
    participant Audio as AudioEngine
    participant Tap as AudioTap
    participant Req as RecognitionRequest
    participant Task as RecognitionTask
    participant SF as SFSpeechRecognizer
    participant Handler as ResultHandler

    Audio->>Audio: start()
    Audio->>Tap: installTap(bufferSize: 512)

    loop Every 32ms (512 frames @ 16kHz)
        Audio->>Tap: audioBuffer
        Tap->>Req: append(buffer)
    end

    SF->>Task: recognitionTask(with: request)

    loop Recognition Active
        Task->>SF: processAudio()
        SF-->>Task: SFSpeechRecognitionResult

        alt Has Partial Result
            Task->>Handler: result.bestTranscription
            Handler->>Handler: updatePartialText()
        end

        alt Is Final
            Task->>Handler: result (isFinal: true)
            Handler->>Handler: commitFinalText()
        end
    end
```

---

## WF-STT-003: Partial Result Processing

Handle interim transcription results.

```mermaid
sequenceDiagram
    participant Task as RecognitionTask
    participant Handler as ResultHandler
    participant VM as ViewModel
    participant UI as TranscriptView
    participant Conf as ConfidenceFilter

    Task->>Handler: result (isFinal: false)
    Handler->>Handler: extractBestTranscription()

    Handler->>Conf: filterByConfidence(segments)
    Conf->>Conf: check segment.confidence >= 0.5
    Conf-->>Handler: filteredSegments

    Handler->>VM: partialResult(text, confidence)
    VM->>VM: updateCurrentSegment(text)

    VM->>UI: refresh()
    UI->>UI: displayPartialText(style: .provisional)
    Note over UI: Show with lighter color / italic
```

---

## WF-STT-004: Final Result Processing

Confirmed transcription handling and forwarding.

```mermaid
sequenceDiagram
    participant Task as RecognitionTask
    participant Handler as ResultHandler
    participant VM as InterpretationViewModel
    participant Trans as TranslationManager
    participant Data as ConversationRepository

    Task->>Handler: result (isFinal: true)
    Handler->>Handler: extractFinalTranscription()

    Handler->>VM: finalResult(text, confidence, duration)
    VM->>VM: commitSegment()

    par Parallel Processing
        VM->>Trans: translate(text, source, target)
        and
        VM->>Data: saveTranscriptItem(original: text)
    end

    Trans-->>VM: translatedText
    VM->>Data: updateTranscriptItem(translated: text)
    VM->>VM: triggerTTS(translatedText)
```

---

## WF-STT-005: Pause Detection

Silence-based segment splitting.

```mermaid
sequenceDiagram
    participant Audio as AudioEngine
    participant VAD as VoiceActivityDetector
    participant Pause as PauseDetector
    participant Timer as SilenceTimer
    participant STT as SpeechRecognitionManager

    loop Audio Processing
        Audio->>VAD: audioBuffer
        VAD->>VAD: calculateRMS()

        alt RMS > threshold (-40dB)
            VAD-->>Pause: voiceActive: true
            Pause->>Timer: cancel()
        else RMS <= threshold
            VAD-->>Pause: voiceActive: false
            Pause->>Timer: start(duration: 500ms)
        end
    end

    Timer->>Timer: wait 500ms

    alt No Voice Detected for 500ms
        Timer-->>Pause: timeout
        Pause->>STT: segmentComplete()
        STT->>STT: finishCurrentRequest()
        STT->>STT: createNewRequest()
        Note over STT: New segment starts
    else Voice Resumes
        Timer->>Timer: cancelled
        Note over STT: Continue current segment
    end
```

---

## WF-STT-006: Speaker Diarization

Dual speaker identification for conversations.

```mermaid
sequenceDiagram
    participant Audio as AudioEngine
    participant Dia as SpeakerDiarizer
    participant Embed as EmbeddingExtractor
    participant Cluster as ClusterAnalyzer
    participant STT as SpeechRecognitionManager

    Audio->>Dia: audioSegment
    Dia->>Embed: extractEmbedding(segment)
    Embed-->>Dia: voiceEmbedding (vector)

    alt First Segment
        Dia->>Cluster: initializeSpeaker(embedding)
        Cluster->>Cluster: speaker0 = embedding
        Dia-->>STT: speakerID: 0
    else Subsequent Segments
        Dia->>Cluster: identifySpeaker(embedding)
        Cluster->>Cluster: calculateSimilarity()

        alt Similar to Speaker 0
            Cluster-->>Dia: speakerID: 0
        else Similar to Speaker 1
            Cluster-->>Dia: speakerID: 1
        else New Speaker (if < 2 speakers)
            Cluster->>Cluster: speaker1 = embedding
            Cluster-->>Dia: speakerID: 1
        end

        Dia-->>STT: speakerID
    end

    STT->>STT: tagTranscriptWithSpeaker(speakerID)
```

---

## WF-STT-007: WhisperKit Fallback

Offline recognition when SFSpeechRecognizer unavailable.

```mermaid
sequenceDiagram
    participant STT as SpeechRecognitionManager
    participant SF as SFSpeechRecognizer
    participant WK as WhisperKit
    participant Model as LocalModel

    STT->>SF: checkAvailability()
    SF-->>STT: isAvailable: false

    STT->>WK: initialize()
    WK->>Model: loadModel(tiny/base)
    Model-->>WK: model loaded

    WK-->>STT: ready

    loop Recognition
        STT->>WK: transcribe(audioBuffer)
        WK->>WK: preprocessAudio()
        WK->>Model: inference()
        Model-->>WK: tokens
        WK->>WK: decodeTokens()
        WK-->>STT: transcription
    end

    Note over STT: Same API surface as SFSpeechRecognizer
```

---

## WF-STT-008: Language Auto-Detection

Automatic language identification from speech.

```mermaid
sequenceDiagram
    participant Audio as AudioEngine
    participant Detector as LanguageDetector
    participant SF1 as SFSpeechRecognizer (ja)
    participant SF2 as SFSpeechRecognizer (en)
    participant SF3 as SFSpeechRecognizer (zh)
    participant STT as SpeechRecognitionManager

    Audio->>Detector: initialAudioBuffer (2 seconds)

    par Parallel Recognition
        Detector->>SF1: recognize(buffer)
        SF1-->>Detector: {confidence: 0.92, text: "..."}
        and
        Detector->>SF2: recognize(buffer)
        SF2-->>Detector: {confidence: 0.45, text: "..."}
        and
        Detector->>SF3: recognize(buffer)
        SF3-->>Detector: {confidence: 0.30, text: "..."}
    end

    Detector->>Detector: selectHighestConfidence()
    Note over Detector: threshold >= 0.8

    alt Confidence >= 0.8
        Detector-->>STT: detectedLanguage: ja-JP
        STT->>STT: setSourceLanguage(ja-JP)
    else Low Confidence
        Detector-->>STT: detectionFailed
        STT->>STT: useDefaultLanguage()
    end
```

---

## STT State Diagram

```mermaid
stateDiagram-v2
    [*] --> Uninitialized

    Uninitialized --> CheckingPermission: initialize()
    CheckingPermission --> PermissionDenied: denied
    CheckingPermission --> Initializing: authorized

    PermissionDenied --> [*]

    Initializing --> Ready: success
    Initializing --> UsingFallback: SFSpeech unavailable
    UsingFallback --> Ready: WhisperKit loaded

    Ready --> Listening: startRecognition()
    Listening --> Recognizing: speechDetected

    Recognizing --> PartialResult: interim result
    PartialResult --> Recognizing: continue

    Recognizing --> FinalResult: pause detected
    FinalResult --> Listening: segment complete

    Listening --> Paused: pauseRecognition()
    Paused --> Listening: resumeRecognition()

    Listening --> Ready: stopRecognition()
    Recognizing --> Ready: stopRecognition()

    Ready --> [*]
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
