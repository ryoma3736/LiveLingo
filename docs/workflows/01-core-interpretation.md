# LiveLingo - Core Interpretation Workflows

## WF-CORE-001: Main Interpretation Loop

Complete end-to-end interpretation pipeline from audio input to audio output.

```mermaid
sequenceDiagram
    participant User
    participant UI as InterpretationView
    participant VM as InterpretationViewModel
    participant STT as SpeechRecognitionManager
    participant TRN as TranslationManager
    participant TTS as TTSManager
    participant AUD as AudioSessionManager

    User->>UI: Tap Start Button
    UI->>VM: startInterpretation()

    VM->>AUD: configureSession(playAndRecord)
    AUD-->>VM: configured

    VM->>AUD: activateSession()
    AUD-->>VM: activated

    VM->>STT: startRecognition(sourceLanguage)
    STT->>STT: installAudioTap()
    STT-->>VM: recognition started

    loop Real-time Processing
        User->>STT: Speak
        STT->>STT: processAudioBuffer()
        STT-->>VM: partialResult(text)
        VM->>UI: updateTranscript(partial)

        alt Pause Detected
            STT-->>VM: finalResult(segment)
            VM->>TRN: translate(segment, source, target)
            TRN-->>VM: translatedText
            VM->>UI: updateTranscript(final)
            VM->>TTS: speak(translatedText, targetLanguage)
            TTS->>AUD: playAudio()
            AUD-->>User: Audio Output
        end
    end

    User->>UI: Tap Stop Button
    UI->>VM: stopInterpretation()
    VM->>STT: stopRecognition()
    VM->>TTS: stopSpeaking()
    VM->>AUD: deactivateSession()
    VM->>VM: saveConversation()
    VM-->>UI: interpretation ended
```

---

## WF-CORE-002: Streaming Interpretation (Wait-k Strategy)

Low-latency streaming translation using Wait-k algorithm.

```mermaid
sequenceDiagram
    participant STT as SpeechRecognitionManager
    participant BUF as TokenBuffer
    participant TRN as StreamingTranslator
    participant TTS as TTSManager
    participant Player as AudioPlayer

    STT->>BUF: yield(token1)
    STT->>BUF: yield(token2)
    STT->>BUF: yield(token3)

    Note over BUF: k=3 tokens buffered

    BUF->>TRN: translateSegment([token1,token2,token3])
    TRN-->>TTS: translatedSegment1
    TTS->>Player: enqueueAudio(segment1)

    STT->>BUF: yield(token4)
    STT->>BUF: yield(token5)
    STT->>BUF: yield(token6)

    BUF->>TRN: translateSegment([token4,token5,token6])
    TRN-->>TTS: translatedSegment2
    TTS->>Player: enqueueAudio(segment2)

    Player->>Player: playNext()
    Note over Player: Plays segment1 while segment2 buffers

    Player->>Player: playNext()
    Note over Player: Seamless audio playback
```

---

## WF-CORE-003: Dual Speaker Mode

Two-way interpretation supporting conversations between two speakers.

```mermaid
sequenceDiagram
    participant Speaker1 as Speaker 1 (ja-JP)
    participant Speaker2 as Speaker 2 (en-US)
    participant STT as SpeechRecognitionManager
    participant DIA as SpeakerDiarizer
    participant TRN as TranslationManager
    participant TTS as TTSManager

    Speaker1->>STT: Speak Japanese
    STT->>DIA: audioBuffer
    DIA-->>STT: speakerID: 0
    STT-->>TRN: {text, speakerID: 0}

    TRN->>TRN: translate(ja -> en)
    TRN-->>TTS: englishText
    TTS->>Speaker2: Play English Audio

    Speaker2->>STT: Speak English
    STT->>DIA: audioBuffer
    DIA-->>STT: speakerID: 1
    STT-->>TRN: {text, speakerID: 1}

    TRN->>TRN: translate(en -> ja)
    TRN-->>TTS: japaneseText
    TTS->>Speaker1: Play Japanese Audio

    Note over Speaker1, Speaker2: Conversation continues bidirectionally
```

---

## WF-CORE-004: Single Speaker Mode

One-way interpretation for presentations or announcements.

```mermaid
sequenceDiagram
    participant Speaker
    participant Audience
    participant STT as SpeechRecognitionManager
    participant TRN as TranslationManager
    participant TTS as TTSManager
    participant Display as TranscriptDisplay

    Speaker->>STT: Continuous Speech

    loop For each segment
        STT-->>TRN: recognizedText
        TRN->>TRN: translate(source -> target)

        par Parallel Output
            TRN-->>Display: Show Translation
            and
            TRN-->>TTS: translatedText
            TTS->>Audience: Play Audio
        end
    end
```

---

## WF-CORE-005: Pause Detection & Segment Processing

Automatic segmentation based on speech pauses.

```mermaid
sequenceDiagram
    participant Audio as AudioEngine
    participant VAD as VoiceActivityDetector
    participant STT as SpeechRecognitionManager
    participant Pause as PauseDetector
    participant Proc as SegmentProcessor

    Audio->>VAD: audioBuffer
    VAD-->>STT: voiceDetected: true

    loop Continuous Speech
        Audio->>STT: audioBuffer
        STT->>STT: appendToRequest()
        STT-->>Pause: partialResult

        Pause->>Pause: checkSilenceDuration()
        Note over Pause: threshold: 500ms
    end

    Audio->>VAD: audioBuffer
    VAD-->>Pause: voiceDetected: false

    Pause->>Pause: startSilenceTimer()

    alt Silence >= 500ms
        Pause-->>STT: pauseDetected
        STT->>Proc: finalResult(segment)
        Proc->>Proc: processSegment()
        STT->>STT: resetRecognition()
    else Speech Resumes
        Pause->>Pause: cancelSilenceTimer()
        Note over STT: Continue current segment
    end
```

---

## Complete Pipeline State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Configuring: startInterpretation()
    Configuring --> Listening: audioSession.activated

    Listening --> Recognizing: speechDetected
    Recognizing --> Listening: silence < threshold
    Recognizing --> Translating: pauseDetected

    Translating --> Speaking: translationComplete
    Speaking --> Listening: audioPlaybackComplete

    Listening --> Paused: interruption.began
    Paused --> Listening: interruption.ended

    Listening --> Stopping: stopInterpretation()
    Recognizing --> Stopping: stopInterpretation()
    Translating --> Stopping: stopInterpretation()
    Speaking --> Stopping: stopInterpretation()

    Stopping --> Saving: cleanup complete
    Saving --> Idle: saved

    Idle --> [*]
```

---

## Data Flow Diagram

```mermaid
flowchart TD
    subgraph Input
        MIC[Microphone]
        BT[Bluetooth Headset]
    end

    subgraph STT[Speech Recognition]
        AE[Audio Engine]
        SF[SFSpeechRecognizer]
        WK[WhisperKit Fallback]
    end

    subgraph Translation
        ATF[Apple Translation]
        OAI[OpenAI API]
        ANT[Anthropic API]
        CTX[Context Manager]
    end

    subgraph TTS[Text-to-Speech]
        AVS[AVSpeechSynthesizer]
        CF[CoeFont API]
        PV[Personal Voice]
    end

    subgraph Output
        SPK[Speaker]
        BTO[Bluetooth Output]
    end

    MIC --> AE
    BT --> AE
    AE --> SF
    AE --> WK

    SF --> ATF
    SF --> OAI
    SF --> ANT
    WK --> ATF

    CTX --> ATF
    CTX --> OAI
    CTX --> ANT

    ATF --> AVS
    ATF --> CF
    OAI --> AVS
    OAI --> CF
    ANT --> AVS
    ANT --> CF
    AVS --> PV

    AVS --> SPK
    CF --> SPK
    PV --> SPK
    AVS --> BTO
    CF --> BTO
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
