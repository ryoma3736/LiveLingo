# LiveLingo - Core Pipeline Data Flows

## DF-CORE-001: Complete End-to-End Pipeline

Full interpretation data flow from microphone to speaker.

```mermaid
flowchart TB
    subgraph Input[Audio Input Layer]
        MIC[Microphone<br/>16kHz Mono]
        BT_IN[Bluetooth Input<br/>HFP/A2DP]
    end

    subgraph AudioEngine[Audio Engine Layer]
        SESSION[AVAudioSession<br/>PlayAndRecord]
        ENGINE[AVAudioEngine]
        TAP[Audio Tap<br/>512 frames]
        BUFFER[Buffer Pool<br/>Pre-allocated]
    end

    subgraph Processing[Signal Processing Layer]
        VAD[Voice Activity<br/>Detection]
        PAUSE[Pause Detector<br/>500ms threshold]
        DIA[Speaker<br/>Diarization]
    end

    subgraph STT[Speech Recognition Layer]
        SF[SFSpeechRecognizer<br/>Primary]
        WK[WhisperKit<br/>Fallback]
        PARTIAL[Partial Results]
        FINAL[Final Results]
    end

    subgraph Translation[Translation Layer]
        CTX[Context Manager<br/>Last 5 turns]
        GLOSS[Glossary<br/>Matcher]
        CACHE[Translation<br/>Cache]
        APPLE[Apple Translation]
        OPENAI[OpenAI<br/>GPT-4o-mini]
        ANTHROPIC[Anthropic<br/>Claude-3-haiku]
    end

    subgraph TTS[TTS Layer]
        QUEUE[Audio Queue<br/>Pre-buffer 2]
        AVS[AVSpeechSynthesizer]
        CF[CoeFont API]
        PV[Personal Voice]
    end

    subgraph Output[Audio Output Layer]
        OUT_NODE[Output Node]
        SPK[Speaker]
        BT_OUT[Bluetooth Output]
    end

    subgraph Persistence[Persistence Layer]
        SWIFT_DATA[(SwiftData)]
        TRANSCRIPT[TranscriptItem]
    end

    MIC --> SESSION
    BT_IN --> SESSION
    SESSION --> ENGINE
    ENGINE --> TAP
    TAP --> BUFFER

    BUFFER --> VAD
    BUFFER --> DIA
    VAD --> PAUSE

    BUFFER --> SF
    BUFFER --> WK
    SF --> PARTIAL
    WK --> PARTIAL
    PAUSE --> FINAL
    SF --> FINAL
    WK --> FINAL
    DIA --> FINAL

    FINAL --> CTX
    CTX --> GLOSS
    GLOSS --> CACHE
    CACHE -->|Miss| APPLE
    CACHE -->|Miss| OPENAI
    CACHE -->|Miss| ANTHROPIC
    APPLE --> QUEUE
    OPENAI --> QUEUE
    ANTHROPIC --> QUEUE
    CACHE -->|Hit| QUEUE

    QUEUE --> AVS
    QUEUE --> CF
    AVS --> PV
    AVS --> OUT_NODE
    CF --> OUT_NODE
    PV --> OUT_NODE
    OUT_NODE --> SPK
    OUT_NODE --> BT_OUT

    FINAL --> TRANSCRIPT
    QUEUE --> TRANSCRIPT
    TRANSCRIPT --> SWIFT_DATA
```

---

## DF-CORE-002: Real-time Streaming Data Flow (Wait-k)

Low-latency streaming with token buffering.

```mermaid
flowchart TB
    subgraph TokenStream[Token Stream Input]
        T1[Token 1: Hello]
        T2[Token 2: how]
        T3[Token 3: are]
        T4[Token 4: you]
        T5[Token 5: today]
        T6[Token 6: ?]
    end

    subgraph Buffer[Wait-k Buffer k=3]
        B1[Slot 1]
        B2[Slot 2]
        B3[Slot 3]
    end

    subgraph Translator[Streaming Translator]
        SEG1[Segment 1<br/>Hello how are]
        SEG2[Segment 2<br/>you today ?]
    end

    subgraph Synthesizer[TTS Synthesizer]
        SYNTH1[Synthesize Segment 1]
        SYNTH2[Synthesize Segment 2]
    end

    subgraph AudioQueue[Audio Playback Queue]
        AUD1[Audio 1<br/>Playing]
        AUD2[Audio 2<br/>Buffered]
    end

    subgraph Output[Speaker Output]
        PLAY[Seamless Playback]
    end

    T1 --> B1
    T2 --> B2
    T3 --> B3
    B1 & B2 & B3 --> SEG1

    T4 --> B1
    T5 --> B2
    T6 --> B3
    B1 & B2 & B3 --> SEG2

    SEG1 --> SYNTH1
    SEG2 --> SYNTH2

    SYNTH1 --> AUD1
    SYNTH2 --> AUD2

    AUD1 --> PLAY
    AUD2 --> PLAY
```

---

## DF-CORE-003: Dual Speaker Bidirectional Flow

Two-way interpretation between speakers.

```mermaid
flowchart TB
    subgraph Speaker1[Speaker 1 - Japanese]
        S1_MIC[Microphone]
        S1_SPK[Speaker]
    end

    subgraph Speaker2[Speaker 2 - English]
        S2_MIC[Microphone]
        S2_SPK[Speaker]
    end

    subgraph DiarizationEngine[Speaker Diarization]
        DIA[Speaker ID<br/>Assignment]
        EMB[Voice Embedding<br/>Extraction]
        CLUSTER[Clustering<br/>Analysis]
    end

    subgraph ProcessingPipeline[Processing Pipeline]
        STT[Speech Recognition]
        TRANS[Translation Engine]
        TTS[TTS Synthesis]
    end

    subgraph LanguageRouting[Language Routing]
        ROUTE[Language Router]
        JA_EN[Japanese → English]
        EN_JA[English → Japanese]
    end

    S1_MIC --> DIA
    S2_MIC --> DIA

    DIA --> EMB
    EMB --> CLUSTER
    CLUSTER -->|Speaker 0| ROUTE
    CLUSTER -->|Speaker 1| ROUTE

    DIA --> STT
    STT --> ROUTE

    ROUTE -->|Speaker 0 + JA| JA_EN
    ROUTE -->|Speaker 1 + EN| EN_JA

    JA_EN --> TRANS
    EN_JA --> TRANS

    TRANS --> TTS

    TTS -->|EN Audio| S2_SPK
    TTS -->|JA Audio| S1_SPK
```

---

## DF-CORE-004: Single Speaker Broadcast Flow

One-way interpretation for presentations.

```mermaid
flowchart TB
    subgraph Presenter[Presenter]
        MIC[Microphone Input]
    end

    subgraph Processing[Real-time Processing]
        STT[Speech Recognition<br/>Continuous]
        SEG[Segment Splitter]
        TRANS[Parallel Translation]
    end

    subgraph MultiOutput[Multi-Output Distribution]
        DISPLAY[Transcript Display<br/>Real-time]
        AUDIO[Audio Synthesis]
    end

    subgraph Audience[Audience]
        SCREEN[Visual Display]
        SPEAKERS[Audio Speakers]
    end

    MIC --> STT
    STT --> SEG

    SEG --> TRANS

    TRANS --> DISPLAY
    TRANS --> AUDIO

    DISPLAY --> SCREEN
    AUDIO --> SPEAKERS
```

---

## DF-CORE-005: Pause Detection Segmentation Flow

Automatic segment splitting based on silence.

```mermaid
flowchart TB
    subgraph AudioInput[Audio Input Stream]
        BUFFER[Audio Buffer<br/>512 samples]
    end

    subgraph Analysis[Signal Analysis]
        RMS[RMS Calculator]
        DB[Energy Level<br/>dB]
        THRESHOLD[Threshold<br/>-40dB]
    end

    subgraph Detection[Voice Detection]
        COMPARE[Compare]
        HYST[Hysteresis<br/>Prevent Flutter]
        STATE[Voice State]
    end

    subgraph Timer[Silence Timer]
        START[Start Timer]
        CHECK[Check 500ms]
        CANCEL[Cancel Timer]
    end

    subgraph Output[Segment Output]
        CONTINUE[Continue Segment]
        COMPLETE[Complete Segment]
        NEW[New Segment]
    end

    BUFFER --> RMS
    RMS --> DB
    DB --> COMPARE
    THRESHOLD --> COMPARE

    COMPARE --> HYST
    HYST --> STATE

    STATE -->|Voice Active| CANCEL
    STATE -->|Silence Start| START

    START --> CHECK
    CHECK -->|< 500ms + Voice| CANCEL
    CHECK -->|>= 500ms| COMPLETE

    CANCEL --> CONTINUE
    COMPLETE --> NEW
```

---

## DF-CORE-006: Interruption Handling Flow

Audio session interruption response.

```mermaid
flowchart TB
    subgraph Interruptions[Interruption Sources]
        PHONE[Phone Call]
        SIRI[Siri Activation]
        ALARM[Alarm/Timer]
        OTHER[Other App Audio]
    end

    subgraph Detection[Interruption Detection]
        NOTIFY[AVAudioSession<br/>Notification]
        TYPE[Interruption Type]
        OPTIONS[Options Flags]
    end

    subgraph StateSaving[State Preservation]
        SAVE_STT[Save STT State]
        SAVE_TRANS[Save Translation State]
        SAVE_TTS[Save TTS State]
        SAVE_POS[Save Buffer Position]
    end

    subgraph Recovery[Recovery Actions]
        RESTORE[Restore State]
        RESUME_STT[Resume STT]
        RESUME_TTS[Resume TTS]
        REACTIVATE[Reactivate Session]
    end

    subgraph Decision[Resume Decision]
        SHOULD_RESUME{Should Resume?}
        AUTO[Auto Resume]
        MANUAL[Manual Resume]
        STOP[Stop Session]
    end

    PHONE --> NOTIFY
    SIRI --> NOTIFY
    ALARM --> NOTIFY
    OTHER --> NOTIFY

    NOTIFY --> TYPE
    TYPE --> OPTIONS

    OPTIONS -->|Began| SAVE_STT
    OPTIONS -->|Began| SAVE_TRANS
    OPTIONS -->|Began| SAVE_TTS
    OPTIONS -->|Began| SAVE_POS

    OPTIONS -->|Ended| SHOULD_RESUME

    SHOULD_RESUME -->|Yes + Auto| AUTO
    SHOULD_RESUME -->|Yes + Manual| MANUAL
    SHOULD_RESUME -->|No| STOP

    AUTO --> RESTORE
    MANUAL --> RESTORE
    RESTORE --> RESUME_STT
    RESTORE --> RESUME_TTS
    RESTORE --> REACTIVATE
```

---

## DF-CORE-007: Memory Management Flow

Resource allocation and cleanup.

```mermaid
flowchart TB
    subgraph Monitoring[Memory Monitoring]
        USAGE[Memory Usage<br/>Tracking]
        THRESHOLD75[Warning<br/>> 75%]
        THRESHOLD92[Critical<br/>> 92%]
    end

    subgraph Caches[Cache Resources]
        TRANS_CACHE[Translation Cache]
        AUDIO_BUF[Audio Buffers]
        HISTORY[Conversation History]
    end

    subgraph Cleanup[Emergency Cleanup]
        EVICT_TRANS[Evict Translation Cache]
        RELEASE_BUF[Release Audio Buffers]
        TRUNCATE[Truncate History]
        FORCE_GC[Force GC]
    end

    subgraph States[Memory States]
        OPTIMAL[Optimal<br/>< 75%]
        WARNING[Warning<br/>75-92%]
        CRITICAL[Critical<br/>> 92%]
    end

    USAGE --> THRESHOLD75
    USAGE --> THRESHOLD92

    THRESHOLD75 -->|< 75%| OPTIMAL
    THRESHOLD75 -->|>= 75%| WARNING
    THRESHOLD92 -->|>= 92%| CRITICAL

    WARNING --> EVICT_TRANS
    EVICT_TRANS --> TRANS_CACHE

    CRITICAL --> EVICT_TRANS
    CRITICAL --> RELEASE_BUF
    CRITICAL --> TRUNCATE
    CRITICAL --> FORCE_GC

    RELEASE_BUF --> AUDIO_BUF
    TRUNCATE --> HISTORY
```

---

## DF-CORE-008: Audio Route Change Flow

Dynamic audio route switching.

```mermaid
flowchart TB
    subgraph Devices[Available Devices]
        BUILTIN[Built-in<br/>Mic/Speaker]
        BT[Bluetooth<br/>Headset]
        WIRED[Wired<br/>Headphones]
        AIRPLAY[AirPlay]
    end

    subgraph Detection[Route Detection]
        MONITOR[Route Change<br/>Monitor]
        CURRENT[Current Route]
        AVAILABLE[Available Routes]
    end

    subgraph Selection[Route Selection]
        AUTO[Automatic<br/>Selection]
        PREF[User Preference]
        MANUAL[Manual Override]
    end

    subgraph Handling[Change Handling]
        CONNECTED[Device Connected]
        DISCONNECTED[Device Disconnected]
        FALLBACK[Fallback Route]
    end

    subgraph Adaptation[Pipeline Adaptation]
        RECONFIGURE[Reconfigure<br/>Audio Session]
        UPDATE_IN[Update Input]
        UPDATE_OUT[Update Output]
    end

    BUILTIN --> AVAILABLE
    BT --> AVAILABLE
    WIRED --> AVAILABLE
    AIRPLAY --> AVAILABLE

    AVAILABLE --> MONITOR
    MONITOR --> CURRENT

    PREF --> AUTO
    AUTO --> CURRENT
    MANUAL --> CURRENT

    MONITOR --> CONNECTED
    MONITOR --> DISCONNECTED
    DISCONNECTED --> FALLBACK
    FALLBACK --> CURRENT

    CONNECTED --> RECONFIGURE
    FALLBACK --> RECONFIGURE

    RECONFIGURE --> UPDATE_IN
    RECONFIGURE --> UPDATE_OUT
```

---

## DF-CORE-009: Context Window Management Flow

Conversation context for translation.

```mermaid
flowchart TB
    subgraph Input[New Input]
        ORIGINAL[Original Text]
        TRANSLATED[Translated Text]
        SPEAKER[Speaker ID]
        TIME[Timestamp]
    end

    subgraph Context[Context Manager]
        WINDOW[Rolling Window<br/>Max 10 turns]
        ADD[Add Turn]
        TRIM[Trim Oldest]
    end

    subgraph Storage[Turn Storage]
        T1[Turn 1]
        T2[Turn 2]
        T3[Turn 3]
        T4[Turn 4]
        T5[Turn 5]
    end

    subgraph Retrieval[Context Retrieval]
        GET[Get Recent 5]
        FORMAT[Format for LLM]
    end

    subgraph Usage[Translation Usage]
        PROMPT[Build Prompt]
        LLM[Send to LLM]
    end

    ORIGINAL --> ADD
    TRANSLATED --> ADD
    SPEAKER --> ADD
    TIME --> ADD

    ADD --> WINDOW
    WINDOW -->|> 10| TRIM

    WINDOW --> T1
    WINDOW --> T2
    WINDOW --> T3
    WINDOW --> T4
    WINDOW --> T5

    GET --> T1 & T2 & T3 & T4 & T5
    T1 & T2 & T3 & T4 & T5 --> FORMAT

    FORMAT --> PROMPT
    PROMPT --> LLM
```

---

## DF-CORE-010: Error Recovery Pipeline Flow

Fault-tolerant processing with fallbacks.

```mermaid
flowchart TB
    subgraph STTErrors[STT Errors]
        SF_FAIL[SFSpeech Failure]
        NO_RESULT[No Recognition Result]
        TIMEOUT[Recognition Timeout]
    end

    subgraph STTRecovery[STT Recovery]
        WK_FALLBACK[WhisperKit Fallback]
        RETRY_STT[Retry Recognition]
    end

    subgraph TransErrors[Translation Errors]
        APPLE_FAIL[Apple Trans Failure]
        API_FAIL[API Failure]
        RATE_LIMIT[Rate Limited]
    end

    subgraph TransRecovery[Translation Recovery]
        CLOUD_FALLBACK[Cloud LLM Fallback]
        CACHE_USE[Use Cached]
        RETRY_TRANS[Retry with Backoff]
    end

    subgraph TTSErrors[TTS Errors]
        AVS_FAIL[AVS Failure]
        CF_FAIL[CoeFont Failure]
    end

    subgraph TTSRecovery[TTS Recovery]
        SYSTEM_VOICE[System Voice Fallback]
        SKIP_AUDIO[Skip Audio Output]
    end

    subgraph FinalOutput[Output Handling]
        SUCCESS[Normal Output]
        DEGRADED[Degraded Output]
        NOTIFY[Notify User]
    end

    SF_FAIL --> WK_FALLBACK
    NO_RESULT --> RETRY_STT
    TIMEOUT --> RETRY_STT

    APPLE_FAIL --> CLOUD_FALLBACK
    API_FAIL --> RETRY_TRANS
    RATE_LIMIT --> RETRY_TRANS
    API_FAIL --> CACHE_USE

    AVS_FAIL --> SYSTEM_VOICE
    CF_FAIL --> SYSTEM_VOICE

    WK_FALLBACK --> SUCCESS
    RETRY_STT --> SUCCESS
    CLOUD_FALLBACK --> SUCCESS
    RETRY_TRANS --> SUCCESS
    CACHE_USE --> DEGRADED
    SYSTEM_VOICE --> DEGRADED
    SKIP_AUDIO --> DEGRADED

    DEGRADED --> NOTIFY
```

---

## DF-CORE-011: Latency Budget Distribution Flow

Time allocation across pipeline stages.

```mermaid
flowchart LR
    subgraph Budget[Total Budget: 1000ms]
        AUDIO_IN[Audio Input<br/>32ms]
        STT_PROC[STT Processing<br/>200-300ms]
        TRANS_PROC[Translation<br/>300-500ms]
        TTS_PROC[TTS Synthesis<br/>100-200ms]
        AUDIO_OUT[Audio Start<br/>50ms]
    end

    subgraph Actual[Actual Timing]
        A_START[T+0ms]
        A_BUFFER[T+32ms]
        A_STT[T+332ms]
        A_TRANS[T+832ms]
        A_TTS[T+932ms]
        A_PLAY[T+982ms]
    end

    AUDIO_IN --> STT_PROC
    STT_PROC --> TRANS_PROC
    TRANS_PROC --> TTS_PROC
    TTS_PROC --> AUDIO_OUT

    A_START --> A_BUFFER
    A_BUFFER --> A_STT
    A_STT --> A_TRANS
    A_TRANS --> A_TTS
    A_TTS --> A_PLAY
```

---

## DF-CORE-012: Parallel Processing Distribution Flow

Concurrent task execution.

```mermaid
flowchart TB
    subgraph Input[Input Event]
        FINAL_RESULT[Final STT Result]
    end

    subgraph Parallel[Parallel Tasks]
        SAVE[Save to Storage]
        TRANSLATE[Translate Text]
        UPDATE_UI[Update UI]
        LOG[Log Analytics]
    end

    subgraph Sync[Synchronization]
        BARRIER[Task Barrier]
    end

    subgraph Sequential[Sequential Tasks]
        TTS[Generate TTS]
        PLAY[Play Audio]
    end

    subgraph Complete[Completion]
        DONE[Segment Complete]
    end

    FINAL_RESULT --> SAVE
    FINAL_RESULT --> TRANSLATE
    FINAL_RESULT --> UPDATE_UI
    FINAL_RESULT --> LOG

    SAVE --> BARRIER
    TRANSLATE --> BARRIER
    UPDATE_UI --> BARRIER
    LOG --> BARRIER

    BARRIER --> TTS
    TTS --> PLAY
    PLAY --> DONE
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 12 core pipeline data flows | AI Agent |
