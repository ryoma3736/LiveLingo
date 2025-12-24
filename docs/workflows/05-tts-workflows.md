# LiveLingo - Text-to-Speech (TTS) Workflows

## WF-TTS-001: AVSpeechSynthesizer

System voice synthesis using Apple's built-in TTS.

```mermaid
sequenceDiagram
    participant TTS as TTSManager
    participant AVS as AVSpeechSynthesizer
    participant Utt as AVSpeechUtterance
    participant Voice as AVSpeechSynthesisVoice
    participant Audio as AudioSessionManager
    participant Delegate as SpeechDelegate

    TTS->>Audio: ensurePlaybackActive()
    Audio-->>TTS: ready

    TTS->>Voice: AVSpeechSynthesisVoice(language: targetLang)
    Voice-->>TTS: voice

    TTS->>Utt: AVSpeechUtterance(string: text)
    TTS->>Utt: voice = voice
    TTS->>Utt: rate = 0.5
    TTS->>Utt: pitchMultiplier = 1.0
    TTS->>Utt: volume = 1.0

    TTS->>AVS: speak(utterance)
    AVS->>Delegate: speechSynthesizer(_:didStart:)
    Delegate-->>TTS: speaking started

    AVS->>AVS: synthesize & play

    AVS->>Delegate: speechSynthesizer(_:didFinish:)
    Delegate-->>TTS: speaking finished
```

---

## WF-TTS-002: CoeFont API Synthesis

AI voice synthesis using CoeFont cloud API.

```mermaid
sequenceDiagram
    participant TTS as TTSManager
    participant Client as CoeFontAPIClient
    participant Auth as HMAC-SHA256
    participant API as CoeFont API
    participant Player as AudioPlayer

    TTS->>Client: synthesize(text, coefontID, speed, pitch)

    Client->>Client: createTimestamp()
    Client->>Client: createRequestBody()
    Note over Client: {coefont, text, speed, pitch}

    Client->>Auth: generateSignature(timestamp, body)
    Auth->>Auth: HMAC-SHA256(timestamp + body, secret)
    Auth-->>Client: signature

    Client->>API: POST /v2/text2speech
    Note over API: Headers:<br/>Authorization: accessKey<br/>X-Coefont-Date: timestamp<br/>X-Coefont-Content: signature

    alt Success (200)
        API-->>Client: audioData (MP3/WAV)
        Client-->>TTS: audioData
        TTS->>Player: play(audioData)
    else Rate Limited (429)
        API-->>Client: error
        Client->>Client: wait(retryAfter)
        Client->>API: retry request
    else Auth Failed (401)
        API-->>Client: error
        Client-->>TTS: throw authenticationFailed
    end
```

---

## WF-TTS-003: Personal Voice (iOS 17+)

User's personal voice synthesis.

```mermaid
sequenceDiagram
    participant TTS as TTSManager
    participant PV as PersonalVoiceManager
    participant Auth as PersonalVoiceAuthorization
    participant AVS as AVSpeechSynthesizer
    participant Voice as PersonalVoice

    TTS->>PV: checkAvailability()

    PV->>Auth: requestAuthorization()
    Auth-->>PV: authorizationStatus

    alt Authorized
        PV->>PV: fetchPersonalVoices()
        PV-->>TTS: [PersonalVoice]

        TTS->>Voice: select first available
        TTS->>AVS: AVSpeechUtterance(string: text)
        AVS->>AVS: utterance.voice = personalVoice

        AVS->>AVS: speak(utterance)
        Note over AVS: Uses user's cloned voice
    else Not Authorized
        PV-->>TTS: personalVoiceNotAvailable
        TTS->>TTS: fallbackToSystemVoice()
    else No Personal Voice Created
        PV-->>TTS: noPersonalVoice
        TTS->>TTS: promptUserToCreate()
    end
```

---

## WF-TTS-004: Streaming Audio Playback

Pre-buffered audio queue for seamless playback.

```mermaid
sequenceDiagram
    participant TRN as TranslationStream
    participant TTS as PreBufferedTTS
    participant Synth as Synthesizer
    participant Queue as AudioQueue
    participant Player as AudioPlayer

    Note over TTS: bufferAheadCount = 2

    TRN->>TTS: textStream.yield("Segment 1")
    TTS->>Synth: synthesize("Segment 1")
    Synth-->>Queue: enqueue(audio1)

    TRN->>TTS: textStream.yield("Segment 2")
    TTS->>Synth: synthesize("Segment 2")
    Synth-->>Queue: enqueue(audio2)

    Note over Queue: buffer.count >= 2<br/>Start playback!

    Queue->>Player: playNext()
    Player->>Player: play(audio1)

    TRN->>TTS: textStream.yield("Segment 3")
    TTS->>Synth: synthesize("Segment 3")
    Synth-->>Queue: enqueue(audio3)

    Player->>Queue: audio1 finished
    Queue->>Player: playNext()
    Player->>Player: play(audio2)

    Note over Player: Seamless transition<br/>No gaps between segments
```

---

## WF-TTS-005: Voice Selection

Choose and configure TTS voices.

```mermaid
sequenceDiagram
    participant User
    participant UI as VoiceSelectionView
    participant TTS as TTSManager
    participant AVS as AVSpeechSynthesizer
    participant CF as CoeFontClient
    participant Store as VoicePreferenceStore

    User->>UI: Open Voice Settings

    par Load Available Voices
        UI->>AVS: AVSpeechSynthesisVoice.speechVoices()
        AVS-->>UI: [systemVoices]
        and
        UI->>CF: getAvailableVoices()
        CF-->>UI: [coefontVoices]
    end

    UI->>UI: groupByLanguage(voices)
    UI->>User: Display Voice List

    User->>UI: Select Voice
    User->>UI: Adjust Settings (rate, pitch)

    UI->>TTS: previewVoice(voice, sampleText)
    TTS->>TTS: speak(sampleText, voice)
    TTS-->>User: Play Preview

    User->>UI: Confirm Selection
    UI->>Store: savePreference(languageCode, voiceID, settings)
    Store-->>UI: saved

    UI-->>User: Voice Updated
```

---

## TTS Provider Selection Flow

```mermaid
flowchart TD
    A[TTS Request] --> B{User Preference}

    B -->|System Voice| C[AVSpeechSynthesizer]
    B -->|AI Voice| D{Network Available?}
    B -->|Personal Voice| E{Personal Voice<br/>Available?}

    D -->|Yes| F[CoeFont API]
    D -->|No| G[Fallback to System]

    E -->|Yes| H[Personal Voice]
    E -->|No| I[Prompt to Create]

    C --> J[Speak]
    F --> J
    G --> J
    H --> J

    I --> K[Open Settings]
```

---

## Audio Session Configuration for TTS

```mermaid
sequenceDiagram
    participant TTS as TTSManager
    participant Session as AVAudioSession
    participant Route as AudioRoute

    TTS->>Session: setCategory(.playAndRecord)
    TTS->>Session: setMode(.voiceChat)
    TTS->>Session: setOptions([.defaultToSpeaker, .allowBluetooth])

    TTS->>Session: setActive(true)

    TTS->>Route: getCurrentRoute()
    Route-->>TTS: outputs: [speaker/bluetooth]

    alt Bluetooth Connected
        Note over TTS: Audio plays through Bluetooth
    else No Bluetooth
        TTS->>Session: overrideOutputAudioPort(.speaker)
        Note over TTS: Audio plays through speaker
    end

    TTS->>TTS: startSpeaking()
```

---

## TTS State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Preparing: speak(text)
    Preparing --> Synthesizing: voice selected

    Synthesizing --> Buffering: audio generated
    Buffering --> Playing: buffer ready

    Playing --> Playing: next segment
    Playing --> Idle: all segments complete

    Playing --> Paused: pause()
    Paused --> Playing: resume()
    Paused --> Idle: stop()

    Playing --> Idle: stop()
    Synthesizing --> Idle: error

    Idle --> [*]
```

---

## Voice Quality Comparison

```mermaid
sequenceDiagram
    participant Bench as Benchmark
    participant AVS as AVSpeechSynthesizer
    participant CF as CoeFont
    participant PV as PersonalVoice
    participant Eval as Evaluator

    Bench->>Bench: loadTestSentences()

    loop For each sentence
        par Synthesize
            Bench->>AVS: synthesize(sentence)
            AVS-->>Bench: {audio, latency: 50ms}
            and
            Bench->>CF: synthesize(sentence)
            CF-->>Bench: {audio, latency: 200ms}
            and
            Bench->>PV: synthesize(sentence)
            PV-->>Bench: {audio, latency: 80ms}
        end

        Bench->>Eval: evaluate(audioSamples)
        Eval->>Eval: measureMOS()
        Eval->>Eval: measureNaturalness()
        Eval-->>Bench: scores
    end

    Bench->>Bench: generateReport()
    Note over Bench: AVS: Fast, decent quality<br/>CoeFont: Slow, high quality<br/>PV: Medium, personalized
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
