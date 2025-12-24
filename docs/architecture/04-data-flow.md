# LiveLingo - Data Flow Architecture

## End-to-End Interpretation Data Flow

```mermaid
flowchart TB
    subgraph Input[Audio Input]
        Mic[Microphone<br/>16kHz, 16-bit]
    end

    subgraph STT[Speech Recognition]
        AE[AVAudioEngine]
        Tap[Audio Tap<br/>512 frames/32ms]
        SF[SFSpeechRecognizer]
        Partial[Partial Results]
        Final[Final Results]
    end

    subgraph Translation[Translation Engine]
        Context[Context Manager<br/>Last 5 turns]
        Glossary[Glossary Matcher]
        Provider[Translation Provider<br/>Apple/OpenAI/Anthropic]
        Cache[Translation Cache]
    end

    subgraph TTS[Text-to-Speech]
        Queue[Audio Queue<br/>Pre-buffer 2 segments]
        Synth[Synthesizer<br/>AVS/CoeFont]
    end

    subgraph Output[Audio Output]
        Speaker[Speaker/Bluetooth]
    end

    subgraph Persistence[Data Persistence]
        SwiftData[(SwiftData<br/>Conversation)]
        Transcript[TranscriptItem]
    end

    Mic --> AE
    AE --> Tap
    Tap --> SF
    SF --> Partial
    SF --> Final

    Final --> Context
    Context --> Glossary
    Glossary --> Cache
    Cache -->|Miss| Provider
    Cache -->|Hit| Queue
    Provider --> Queue

    Queue --> Synth
    Synth --> Speaker

    Final --> Transcript
    Provider --> Transcript
    Transcript --> SwiftData
```

---

## Real-time Streaming Data Flow (Wait-k)

```mermaid
flowchart LR
    subgraph Stream[Token Stream]
        T1[Token 1]
        T2[Token 2]
        T3[Token 3]
        T4[Token 4]
        T5[Token 5]
        T6[Token 6]
    end

    subgraph Buffer[Wait-k Buffer<br/>k=3]
        B1[Slot 1]
        B2[Slot 2]
        B3[Slot 3]
    end

    subgraph TransStream[Translation Stream]
        TS1[Segment 1]
        TS2[Segment 2]
    end

    subgraph AudioStream[Audio Stream]
        AS1[Audio 1]
        AS2[Audio 2]
    end

    T1 --> B1
    T2 --> B2
    T3 --> B3
    B1 & B2 & B3 --> TS1
    TS1 --> AS1

    T4 --> B1
    T5 --> B2
    T6 --> B3
    B1 & B2 & B3 --> TS2
    TS2 --> AS2
```

---

## User Input Data Flow

```mermaid
flowchart TB
    subgraph UserActions[User Actions]
        Tap[Tap/Touch]
        Speak[Voice Input]
        Swipe[Swipe Gesture]
        Type[Text Input]
    end

    subgraph Views[SwiftUI Views]
        Button[Button Action]
        Speech[Audio Capture]
        Gesture[Gesture Handler]
        TextField[Text Field]
    end

    subgraph ViewModels[ViewModels]
        Intent[User Intent]
        Validation[Input Validation]
        Transform[Data Transform]
    end

    subgraph UseCases[Use Cases]
        Start[StartInterpretation]
        Stop[StopInterpretation]
        Save[SaveConversation]
        Change[ChangeLanguage]
    end

    subgraph Effects[Side Effects]
        Audio[Audio Processing]
        Network[Network Request]
        Storage[Data Storage]
        UI[UI Update]
    end

    Tap --> Button
    Speak --> Speech
    Swipe --> Gesture
    Type --> TextField

    Button --> Intent
    Speech --> Intent
    Gesture --> Intent
    TextField --> Intent

    Intent --> Validation
    Validation --> Transform
    Transform --> Start
    Transform --> Stop
    Transform --> Save
    Transform --> Change

    Start --> Audio
    Stop --> Storage
    Save --> Storage
    Change --> Network
    Change --> UI
```

---

## State Data Flow

```mermaid
flowchart TB
    subgraph Sources[State Sources]
        User[User Action]
        System[System Event]
        Network[Network Response]
        Timer[Timer Event]
    end

    subgraph StateManagement[State Management]
        subgraph AppState[App State]
            Auth[Auth State]
            Nav[Navigation State]
            Settings[Settings State]
        end

        subgraph FeatureState[Feature State]
            Interp[Interpretation State]
            Lang[Language State]
            Audio[Audio State]
        end
    end

    subgraph Observers[State Observers]
        Views[SwiftUI Views]
        Managers[Managers]
        Analytics[Analytics]
    end

    User --> AppState
    User --> FeatureState
    System --> AppState
    System --> FeatureState
    Network --> FeatureState
    Timer --> FeatureState

    AppState --> Views
    FeatureState --> Views
    FeatureState --> Managers
    AppState --> Analytics
```

---

## API Request/Response Flow

```mermaid
flowchart TB
    subgraph Request[Request Flow]
        Create[Create Request]
        Auth[Add Auth Headers]
        Sign[Sign Request<br/>HMAC-SHA256]
        Send[Send Request]
    end

    subgraph Network[Network Layer]
        Session[URLSession]
        TLS[TLS 1.3]
        Internet((Internet))
    end

    subgraph API[External API]
        Server[API Server]
        Process[Process Request]
        Generate[Generate Response]
    end

    subgraph Response[Response Flow]
        Receive[Receive Response]
        Validate[Validate Response]
        Parse[Parse JSON/Data]
        Cache[Cache Response]
        Return[Return to Caller]
    end

    Create --> Auth
    Auth --> Sign
    Sign --> Send
    Send --> Session
    Session --> TLS
    TLS --> Internet
    Internet --> Server
    Server --> Process
    Process --> Generate
    Generate --> Internet
    Internet --> TLS
    TLS --> Session
    Session --> Receive
    Receive --> Validate
    Validate --> Parse
    Parse --> Cache
    Cache --> Return
```

---

## Caching Data Flow

```mermaid
flowchart TB
    subgraph Request[Cache Request]
        Query[Translation Query<br/>text + source + target]
    end

    subgraph Memory[Memory Cache]
        MemLookup[Memory Lookup]
        MemHit{Hit?}
        MemStore[Store in Memory]
    end

    subgraph Disk[Disk Cache]
        DiskLookup[Disk Lookup]
        DiskHit{Hit?}
        DiskStore[Store on Disk]
    end

    subgraph API[API Call]
        Translate[Call Translation API]
    end

    subgraph Response[Cache Response]
        Return[Return Translation]
    end

    subgraph Eviction[Cache Eviction]
        LRU[LRU Algorithm]
        Expire[TTL Expiration<br/>1 hour]
        Pressure[Memory Pressure]
    end

    Query --> MemLookup
    MemLookup --> MemHit
    MemHit -->|Yes| Return
    MemHit -->|No| DiskLookup
    DiskLookup --> DiskHit
    DiskHit -->|Yes| MemStore
    MemStore --> Return
    DiskHit -->|No| Translate
    Translate --> MemStore
    MemStore --> DiskStore
    DiskStore --> Return

    LRU --> Memory
    Expire --> Memory
    Expire --> Disk
    Pressure --> Memory
```

---

## Error Propagation Flow

```mermaid
flowchart TB
    subgraph Sources[Error Sources]
        Net[Network Error]
        API[API Error]
        Parse[Parse Error]
        Auth[Auth Error]
        System[System Error]
    end

    subgraph Handling[Error Handling]
        Catch[Error Catch]
        Map[Error Mapping]
        Decide[Decision Logic]
    end

    subgraph Actions[Error Actions]
        Retry[Retry with Backoff]
        Fallback[Use Fallback]
        Recover[Auto Recover]
        Propagate[Propagate Up]
    end

    subgraph UI[User Interface]
        Banner[Error Banner]
        Alert[Error Alert]
        Toast[Error Toast]
        Log[Error Log]
    end

    Net --> Catch
    API --> Catch
    Parse --> Catch
    Auth --> Catch
    System --> Catch

    Catch --> Map
    Map --> Decide

    Decide -->|Retryable| Retry
    Decide -->|Has Fallback| Fallback
    Decide -->|Recoverable| Recover
    Decide -->|Critical| Propagate

    Propagate --> Banner
    Propagate --> Alert
    Retry -->|Failed| Toast
    Fallback --> Toast
    Catch --> Log
```

---

## iCloud Sync Data Flow

```mermaid
flowchart TB
    subgraph Device1[Device A]
        Local1[Local SwiftData]
        Change1[Local Change]
    end

    subgraph CloudKit[CloudKit]
        CK[CloudKit Database]
        Sync[Sync Engine]
        Notify[Push Notification]
    end

    subgraph Device2[Device B]
        Local2[Local SwiftData]
        Apply2[Apply Changes]
    end

    subgraph Conflict[Conflict Resolution]
        Detect[Detect Conflict]
        Resolve[Resolve Strategy<br/>Last Write Wins]
        Merge[Merge Changes]
    end

    Change1 --> Local1
    Local1 --> Sync
    Sync --> CK
    CK --> Notify
    Notify --> Sync
    Sync --> Apply2
    Apply2 --> Local2

    Sync --> Detect
    Detect --> Resolve
    Resolve --> Merge
    Merge --> Local1
    Merge --> Local2
```

---

## Lifecycle Data Flow

```mermaid
flowchart TB
    subgraph Launch[App Launch]
        Cold[Cold Start]
        Warm[Warm Start]
    end

    subgraph Init[Initialization]
        DI[Dependency Injection]
        Auth[Check Auth State]
        Perm[Check Permissions]
        Load[Load Settings]
    end

    subgraph Active[Active State]
        Running[App Running]
        Recording[Recording Audio]
        Translating[Translating]
        Playing[Playing Audio]
    end

    subgraph Background[Background State]
        Suspend[Suspended]
        BGAudio[Background Audio]
        Save[Save State]
    end

    subgraph Terminate[Termination]
        Cleanup[Cleanup Resources]
        Persist[Persist Data]
        Release[Release Handles]
    end

    Cold --> DI
    Warm --> Auth
    DI --> Auth
    Auth --> Perm
    Perm --> Load
    Load --> Running

    Running --> Recording
    Recording --> Translating
    Translating --> Playing
    Playing --> Running

    Running --> Suspend
    Recording --> BGAudio
    Suspend --> Save
    BGAudio --> Save

    Save --> Warm
    Suspend --> Cleanup
    Cleanup --> Persist
    Persist --> Release
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
