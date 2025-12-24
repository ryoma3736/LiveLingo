# LiveLingo - Speech Recognition (STT) Data Flows

## DF-STT-001: SFSpeechRecognizer Initialization Flow

Complete initialization with permission handling.

```mermaid
flowchart TB
    subgraph Trigger[Initialization Trigger]
        APP_START[App Start]
        FIRST_USE[First Interpretation]
    end

    subgraph Permission[Permission Check]
        CHECK_PERM[Check Speech Permission]
        NOT_DET{Not Determined?}
        REQUEST[Request Authorization]
        STATUS[Authorization Status]
    end

    subgraph Decision[Authorization Decision]
        AUTHORIZED{Authorized?}
        DENIED[Permission Denied]
        RESTRICTED[Restricted]
    end

    subgraph Initialization[Recognizer Initialization]
        CREATE_SF[Create SFSpeechRecognizer<br/>locale: source language]
        CHECK_AVAIL{isAvailable?}
    end

    subgraph AudioSetup[Audio Engine Setup]
        CREATE_ENGINE[Create AVAudioEngine]
        PREPARE[Prepare Engine]
        FORMAT[Audio Format<br/>16kHz Mono PCM]
    end

    subgraph Fallback[Fallback Path]
        INIT_WK[Initialize WhisperKit]
        LOAD_MODEL[Load tiny/base Model]
    end

    subgraph Ready[Ready State]
        STT_READY[STT Ready]
        OFFLINE_READY[Offline Mode Ready]
    end

    APP_START --> CHECK_PERM
    FIRST_USE --> CHECK_PERM

    CHECK_PERM --> NOT_DET
    NOT_DET -->|Yes| REQUEST
    NOT_DET -->|No| STATUS
    REQUEST --> STATUS

    STATUS --> AUTHORIZED
    AUTHORIZED -->|Yes| CREATE_SF
    AUTHORIZED -->|No| DENIED
    AUTHORIZED -->|Restricted| RESTRICTED

    CREATE_SF --> CHECK_AVAIL
    CHECK_AVAIL -->|Yes| CREATE_ENGINE
    CHECK_AVAIL -->|No| INIT_WK

    CREATE_ENGINE --> PREPARE
    PREPARE --> FORMAT
    FORMAT --> STT_READY

    INIT_WK --> LOAD_MODEL
    LOAD_MODEL --> OFFLINE_READY
```

---

## DF-STT-002: Real-time Audio Processing Flow

Continuous audio buffer processing.

```mermaid
flowchart TB
    subgraph AudioCapture[Audio Capture]
        MIC[Microphone]
        INPUT_NODE[Input Node]
    end

    subgraph Tap[Audio Tap Installation]
        INSTALL[Install Tap<br/>bus: 0]
        BUFFER_SIZE[Buffer Size: 512]
        SAMPLE_RATE[Sample Rate: 16kHz]
    end

    subgraph BufferPool[Buffer Pool Management]
        ACQUIRE[Acquire Buffer]
        POOL[Pre-allocated Pool<br/>Max: 10]
        RELEASE[Release Buffer]
    end

    subgraph Processing[Buffer Processing]
        FILL[Fill Buffer]
        TIMESTAMP[Add Timestamp]
        APPEND[Append to Request]
    end

    subgraph Recognition[Recognition Task]
        REQUEST[Recognition Request]
        TASK[Recognition Task]
        PROCESS[Process Audio]
    end

    subgraph Results[Result Handling]
        PARTIAL[Partial Result]
        FINAL[Final Result]
        ERROR[Error Handler]
    end

    MIC --> INPUT_NODE
    INPUT_NODE --> INSTALL

    INSTALL --> BUFFER_SIZE
    INSTALL --> SAMPLE_RATE

    BUFFER_SIZE --> ACQUIRE
    ACQUIRE --> POOL
    POOL --> FILL

    FILL --> TIMESTAMP
    TIMESTAMP --> APPEND
    APPEND --> REQUEST

    REQUEST --> TASK
    TASK --> PROCESS

    PROCESS --> PARTIAL
    PROCESS --> FINAL
    PROCESS --> ERROR

    PARTIAL --> RELEASE
    FINAL --> RELEASE
    ERROR --> RELEASE
    RELEASE --> POOL
```

---

## DF-STT-003: Partial Result Processing Flow

Interim transcription result handling.

```mermaid
flowchart TB
    subgraph Input[Recognition Result]
        RESULT[SFSpeechRecognitionResult<br/>isFinal: false]
    end

    subgraph Extraction[Data Extraction]
        TRANS[Extract Best Transcription]
        SEGMENTS[Get Segments]
        CONF[Confidence Values]
    end

    subgraph Filtering[Quality Filtering]
        FILTER[Filter by Confidence<br/>>= 0.5]
        VALID[Valid Segments]
        DISCARD[Discarded Segments]
    end

    subgraph Assembly[Text Assembly]
        COMBINE[Combine Segments]
        TEXT[Partial Text]
    end

    subgraph Delivery[Result Delivery]
        VM[ViewModel Update]
        UI[UI Refresh]
        DISPLAY[Display Provisional<br/>Lighter Color/Italic]
    end

    RESULT --> TRANS
    TRANS --> SEGMENTS
    SEGMENTS --> CONF

    CONF --> FILTER
    FILTER --> VALID
    FILTER --> DISCARD

    VALID --> COMBINE
    COMBINE --> TEXT

    TEXT --> VM
    VM --> UI
    UI --> DISPLAY
```

---

## DF-STT-004: Final Result Processing Flow

Confirmed transcription and downstream triggers.

```mermaid
flowchart TB
    subgraph Input[Recognition Result]
        RESULT[SFSpeechRecognitionResult<br/>isFinal: true]
    end

    subgraph Extraction[Data Extraction]
        TRANS[Best Transcription]
        DURATION[Segment Duration]
        CONF[Final Confidence]
        SPEAKER[Speaker ID<br/>from Diarization]
    end

    subgraph Commit[Segment Commit]
        COMMIT[Commit to ViewModel]
        CREATE[Create TranscriptItem]
    end

    subgraph Parallel[Parallel Processing]
        TRANSLATE[Trigger Translation]
        SAVE[Save to Storage]
        UPDATE_UI[Update UI<br/>Final Style]
        ANALYTICS[Log Analytics]
    end

    subgraph Sequential[Sequential Follow-up]
        WAIT[Wait for Translation]
        TTS[Trigger TTS]
    end

    RESULT --> TRANS
    RESULT --> DURATION
    RESULT --> CONF
    RESULT --> SPEAKER

    TRANS --> COMMIT
    DURATION --> COMMIT
    CONF --> COMMIT
    SPEAKER --> COMMIT

    COMMIT --> CREATE

    CREATE --> TRANSLATE
    CREATE --> SAVE
    CREATE --> UPDATE_UI
    CREATE --> ANALYTICS

    TRANSLATE --> WAIT
    WAIT --> TTS
```

---

## DF-STT-005: Voice Activity Detection (VAD) Flow

Voice/silence classification.

```mermaid
flowchart TB
    subgraph Input[Audio Input]
        BUFFER[Audio Buffer<br/>512 samples]
    end

    subgraph Analysis[Signal Analysis]
        SAMPLES[Get Samples]
        SUM_SQ[Sum of Squares]
        MEAN[Mean]
        SQRT[Square Root = RMS]
    end

    subgraph Convert[Level Conversion]
        RMS_VAL[RMS Value]
        DB[Convert to dB<br/>20 * log10(RMS)]
        LEVEL[Energy Level]
    end

    subgraph Threshold[Threshold Comparison]
        THRESHOLD_VAL[Threshold: -40dB]
        COMPARE[Compare Levels]
    end

    subgraph Hysteresis[Hysteresis Filter]
        VOICE_ON[Voice On Threshold<br/>-38dB]
        VOICE_OFF[Voice Off Threshold<br/>-42dB]
        PREVENT[Prevent Flutter]
    end

    subgraph Output[VAD Output]
        ACTIVE[Voice Active]
        INACTIVE[Voice Inactive]
        TRANSITION[State Transition]
    end

    BUFFER --> SAMPLES
    SAMPLES --> SUM_SQ
    SUM_SQ --> MEAN
    MEAN --> SQRT

    SQRT --> RMS_VAL
    RMS_VAL --> DB
    DB --> LEVEL

    LEVEL --> COMPARE
    THRESHOLD_VAL --> COMPARE

    COMPARE --> VOICE_ON
    COMPARE --> VOICE_OFF
    VOICE_ON --> PREVENT
    VOICE_OFF --> PREVENT

    PREVENT --> ACTIVE
    PREVENT --> INACTIVE
    PREVENT --> TRANSITION
```

---

## DF-STT-006: Speaker Diarization Flow

Two-speaker identification.

```mermaid
flowchart TB
    subgraph Input[Voice Segment]
        SEGMENT[Audio Segment<br/>~2 seconds]
    end

    subgraph FeatureExtraction[Feature Extraction]
        MFCC[MFCC Coefficients]
        PITCH[Pitch Analysis]
        FORMANTS[Formant Frequencies]
    end

    subgraph Embedding[Embedding Generation]
        COMBINE[Combine Features]
        NORMALIZE[Normalize]
        VECTOR[128-dim Vector]
    end

    subgraph Comparison[Speaker Comparison]
        KNOWN[Known Speaker Embeddings]
        COSINE[Cosine Similarity]
        THRESHOLD[Threshold: 0.8]
    end

    subgraph Assignment[Speaker Assignment]
        MATCH{Similarity >= 0.8?}
        EXISTING[Assign Existing Speaker]
        NEW_CHECK{< 2 Speakers?}
        NEW_SPEAKER[Create New Speaker]
        ASSIGN[Assign Speaker ID]
    end

    subgraph Output[Diarization Output]
        SPEAKER_0[Speaker 0]
        SPEAKER_1[Speaker 1]
        LABEL[Label Transcript]
    end

    SEGMENT --> MFCC
    SEGMENT --> PITCH
    SEGMENT --> FORMANTS

    MFCC --> COMBINE
    PITCH --> COMBINE
    FORMANTS --> COMBINE

    COMBINE --> NORMALIZE
    NORMALIZE --> VECTOR

    VECTOR --> COSINE
    KNOWN --> COSINE
    COSINE --> THRESHOLD

    THRESHOLD --> MATCH
    MATCH -->|Yes| EXISTING
    MATCH -->|No| NEW_CHECK

    NEW_CHECK -->|Yes| NEW_SPEAKER
    NEW_CHECK -->|No| EXISTING

    NEW_SPEAKER --> ASSIGN
    EXISTING --> ASSIGN

    ASSIGN --> SPEAKER_0
    ASSIGN --> SPEAKER_1
    SPEAKER_0 --> LABEL
    SPEAKER_1 --> LABEL
```

---

## DF-STT-007: WhisperKit Fallback Flow

Offline recognition when SFSpeech unavailable.

```mermaid
flowchart TB
    subgraph Trigger[Fallback Trigger]
        SF_UNAVAIL[SFSpeech Unavailable]
        OFFLINE[Device Offline]
        UNSUPPORTED[Language Unsupported]
    end

    subgraph Initialization[WhisperKit Init]
        CHECK_MODEL[Check Local Model]
        MODEL_EXISTS{Model Cached?}
        DOWNLOAD[Download Model]
        LOAD[Load Model<br/>tiny/base]
    end

    subgraph Processing[Inference Pipeline]
        PREPROCESS[Preprocess Audio<br/>16kHz, Normalize]
        ENCODE[Mel Spectrogram]
        INFER[Model Inference]
        DECODE[Token Decoding]
    end

    subgraph Output[Result Output]
        TOKENS[Generated Tokens]
        TEXT[Transcribed Text]
        TIMESTAMPS[Word Timestamps]
    end

    subgraph Integration[API Integration]
        SAME_API[Same STT API Surface]
        TRANSPARENT[Transparent to Caller]
    end

    SF_UNAVAIL --> CHECK_MODEL
    OFFLINE --> CHECK_MODEL
    UNSUPPORTED --> CHECK_MODEL

    CHECK_MODEL --> MODEL_EXISTS
    MODEL_EXISTS -->|Yes| LOAD
    MODEL_EXISTS -->|No| DOWNLOAD
    DOWNLOAD --> LOAD

    LOAD --> PREPROCESS
    PREPROCESS --> ENCODE
    ENCODE --> INFER
    INFER --> DECODE

    DECODE --> TOKENS
    TOKENS --> TEXT
    TOKENS --> TIMESTAMPS

    TEXT --> SAME_API
    TIMESTAMPS --> SAME_API
    SAME_API --> TRANSPARENT
```

---

## DF-STT-008: Language Auto-Detection Flow

Automatic source language identification.

```mermaid
flowchart TB
    subgraph Input[Initial Audio]
        SAMPLE[Audio Sample<br/>2 seconds]
    end

    subgraph ParallelRecognition[Parallel Recognition]
        SF_JA[SFSpeechRecognizer<br/>ja-JP]
        SF_EN[SFSpeechRecognizer<br/>en-US]
        SF_ZH[SFSpeechRecognizer<br/>zh-CN]
        SF_KO[SFSpeechRecognizer<br/>ko-KR]
    end

    subgraph Results[Recognition Results]
        RES_JA[Result: 0.92 confidence]
        RES_EN[Result: 0.45 confidence]
        RES_ZH[Result: 0.30 confidence]
        RES_KO[Result: 0.25 confidence]
    end

    subgraph Selection[Language Selection]
        COMPARE[Compare Confidences]
        HIGHEST[Select Highest]
        THRESHOLD{>= 0.8?}
    end

    subgraph Decision[Final Decision]
        DETECTED[Detected Language]
        DEFAULT[Use Default Language]
        PROMPT_USER[Prompt User Selection]
    end

    subgraph Apply[Apply Selection]
        SET_SOURCE[Set Source Language]
        CONFIG_STT[Configure STT]
    end

    SAMPLE --> SF_JA
    SAMPLE --> SF_EN
    SAMPLE --> SF_ZH
    SAMPLE --> SF_KO

    SF_JA --> RES_JA
    SF_EN --> RES_EN
    SF_ZH --> RES_ZH
    SF_KO --> RES_KO

    RES_JA --> COMPARE
    RES_EN --> COMPARE
    RES_ZH --> COMPARE
    RES_KO --> COMPARE

    COMPARE --> HIGHEST
    HIGHEST --> THRESHOLD

    THRESHOLD -->|Yes| DETECTED
    THRESHOLD -->|No + Low All| DEFAULT
    THRESHOLD -->|No + Close| PROMPT_USER

    DETECTED --> SET_SOURCE
    DEFAULT --> SET_SOURCE
    PROMPT_USER --> SET_SOURCE

    SET_SOURCE --> CONFIG_STT
```

---

## DF-STT-009: Recognition Error Recovery Flow

Error handling and recovery strategies.

```mermaid
flowchart TB
    subgraph Errors[Error Types]
        NO_SPEECH[No Speech Detected]
        TIMEOUT[Recognition Timeout]
        ENGINE_ERR[Audio Engine Error]
        AUTH_ERR[Authorization Revoked]
    end

    subgraph Assessment[Error Assessment]
        CLASSIFY[Classify Error]
        RETRYABLE{Retryable?}
        COUNT[Attempt Count]
        MAX{Max Retries?}
    end

    subgraph Recovery[Recovery Actions]
        RESET_ENGINE[Reset Audio Engine]
        RECREATE_REQ[Recreate Request]
        RETRY[Retry Recognition]
    end

    subgraph Fallback[Fallback Actions]
        USE_WHISPER[Use WhisperKit]
        NOTIFY_USER[Notify User]
        LOG_ERROR[Log Error]
    end

    subgraph Resume[Resume Operations]
        RESUME_STT[Resume STT]
        CONTINUE[Continue Processing]
    end

    NO_SPEECH --> CLASSIFY
    TIMEOUT --> CLASSIFY
    ENGINE_ERR --> CLASSIFY
    AUTH_ERR --> CLASSIFY

    CLASSIFY --> RETRYABLE

    RETRYABLE -->|Yes| COUNT
    RETRYABLE -->|No| NOTIFY_USER

    COUNT --> MAX
    MAX -->|No| RESET_ENGINE
    MAX -->|Yes| USE_WHISPER

    RESET_ENGINE --> RECREATE_REQ
    RECREATE_REQ --> RETRY
    RETRY --> RESUME_STT

    USE_WHISPER --> RESUME_STT
    RESUME_STT --> CONTINUE

    NOTIFY_USER --> LOG_ERROR
```

---

## DF-STT-010: Recognition Request Lifecycle Flow

Complete request lifecycle management.

```mermaid
flowchart TB
    subgraph Create[Request Creation]
        NEW_REQ[Create Recognition Request]
        TASK_CONFIG[Configure Task Options]
        CALLBACKS[Set Callbacks]
    end

    subgraph Active[Active Recognition]
        START[Start Recognition]
        APPEND[Append Audio]
        PROCESS[Process Continuously]
    end

    subgraph Events[Recognition Events]
        PARTIAL[Partial Results]
        FINAL[Final Results]
        ERROR[Errors]
    end

    subgraph Termination[Request Termination]
        END_AUDIO[End Audio Input]
        WAIT_FINAL[Wait for Final]
        CLEANUP[Cleanup Resources]
    end

    subgraph Restart[Segment Restart]
        NEW_SEGMENT[New Segment]
        CREATE_NEW[Create New Request]
        LINK[Link Context]
    end

    NEW_REQ --> TASK_CONFIG
    TASK_CONFIG --> CALLBACKS
    CALLBACKS --> START

    START --> APPEND
    APPEND --> PROCESS

    PROCESS --> PARTIAL
    PROCESS --> FINAL
    PROCESS --> ERROR

    FINAL --> END_AUDIO
    ERROR --> END_AUDIO

    END_AUDIO --> WAIT_FINAL
    WAIT_FINAL --> CLEANUP

    CLEANUP --> NEW_SEGMENT
    NEW_SEGMENT --> CREATE_NEW
    CREATE_NEW --> LINK
    LINK --> START
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 10 STT data flows | AI Agent |
