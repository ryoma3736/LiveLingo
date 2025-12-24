# LiveLingo - Component Architecture

## Complete Component Diagram

```mermaid
flowchart TB
    subgraph UI[UI Components]
        direction TB
        Home[HomeView]
        Interp[InterpretationView]
        History[HistoryView]
        Settings[SettingsView]
        Onboard[OnboardingView]
        Dict[DictionaryView]
    end

    subgraph ViewModels[ViewModel Components]
        direction TB
        HomeVM[HomeViewModel]
        InterpVM[InterpretationViewModel]
        HistVM[HistoryViewModel]
        SetVM[SettingsViewModel]
        OnbVM[OnboardingViewModel]
    end

    subgraph Core[Core Managers]
        direction TB
        STTMgr[SpeechRecognitionManager]
        TransMgr[TranslationManager]
        TTSMgr[TTSManager]
        AudioMgr[AudioSessionManager]
        LangMgr[LanguageManager]
        PermMgr[PermissionManager]
    end

    subgraph Data[Data Components]
        direction TB
        ConvRepo[ConversationRepository]
        SettRepo[SettingsRepository]
        GlossRepo[GlossaryRepository]
        Cache[TranslationCache]
    end

    subgraph API[API Clients]
        direction TB
        CoeClient[CoeFontAPIClient]
        OAIClient[OpenAIAPIClient]
        AntClient[AnthropicAPIClient]
        NetMgr[NetworkManager]
    end

    subgraph Auth[Authentication]
        direction TB
        AuthMgr[AppleSignInManager]
        BioMgr[BiometricAuthManager]
        KeyMgr[KeychainManager]
    end

    Home --> HomeVM
    Interp --> InterpVM
    History --> HistVM
    Settings --> SetVM
    Onboard --> OnbVM

    InterpVM --> STTMgr
    InterpVM --> TransMgr
    InterpVM --> TTSMgr
    InterpVM --> AudioMgr
    InterpVM --> ConvRepo

    HomeVM --> LangMgr
    HomeVM --> PermMgr

    TransMgr --> Cache
    TransMgr --> OAIClient
    TransMgr --> AntClient

    TTSMgr --> CoeClient

    OAIClient --> NetMgr
    AntClient --> NetMgr
    CoeClient --> NetMgr

    SetVM --> AuthMgr
    SetVM --> SettRepo

    AuthMgr --> BioMgr
    AuthMgr --> KeyMgr
```

---

## Speech Recognition Components

```mermaid
flowchart TB
    subgraph STTComponents[Speech Recognition System]
        subgraph Input[Audio Input]
            Mic[Microphone]
            BT[Bluetooth Input]
        end

        subgraph Engine[Audio Engine]
            AE[AVAudioEngine]
            Tap[Audio Tap]
            Buffer[Audio Buffer Pool]
        end

        subgraph Recognition[Recognition Engines]
            SF[SFSpeechRecognizer<br/>Primary]
            WK[WhisperKit<br/>Fallback]
        end

        subgraph Processing[Processing]
            VAD[Voice Activity Detector]
            Pause[Pause Detector]
            Dia[Speaker Diarizer]
        end

        subgraph Output[Output]
            Partial[Partial Results]
            Final[Final Results]
        end
    end

    Mic --> AE
    BT --> AE
    AE --> Tap
    Tap --> Buffer
    Buffer --> SF
    Buffer --> WK
    Buffer --> VAD

    VAD --> Pause
    SF --> Partial
    WK --> Partial
    Pause --> Final
    SF --> Final
    WK --> Final
    SF --> Dia
```

---

## Translation Components

```mermaid
flowchart TB
    subgraph TransComponents[Translation System]
        subgraph Input[Translation Input]
            Text[Source Text]
            Context[Conversation Context]
            Glossary[Active Glossary]
        end

        subgraph Provider[Translation Providers]
            Apple[Apple Translation<br/>On-device]
            OpenAI[OpenAI GPT-4o-mini<br/>Cloud]
            Anthropic[Anthropic Claude-3<br/>Cloud]
        end

        subgraph Strategy[Translation Strategies]
            Standard[Standard Translation]
            WaitK[Wait-k Streaming]
            Batch[Batch Translation]
        end

        subgraph Cache[Caching Layer]
            MemCache[Memory Cache<br/>LRU, 1000 entries]
            DiskCache[Disk Cache<br/>Persistent]
        end

        subgraph Output[Translation Output]
            Translated[Translated Text]
            Confidence[Confidence Score]
        end
    end

    Text --> Standard
    Text --> WaitK
    Context --> Standard
    Context --> WaitK
    Glossary --> Standard

    Standard --> MemCache
    MemCache -->|Hit| Translated
    MemCache -->|Miss| Apple
    MemCache -->|Miss| OpenAI
    MemCache -->|Miss| Anthropic

    WaitK --> Apple
    WaitK --> OpenAI

    Apple --> Translated
    OpenAI --> Translated
    Anthropic --> Translated
```

---

## TTS Components

```mermaid
flowchart TB
    subgraph TTSComponents[Text-to-Speech System]
        subgraph Input[TTS Input]
            TransText[Translated Text]
            Voice[Voice Selection]
            Settings[Voice Settings]
        end

        subgraph Providers[TTS Providers]
            AVS[AVSpeechSynthesizer<br/>System Voice]
            CF[CoeFont API<br/>AI Voice]
            PV[Personal Voice<br/>iOS 17+]
        end

        subgraph Buffering[Audio Buffering]
            Queue[Audio Queue<br/>Pre-buffer 2 segments]
            Pool[Buffer Pool]
        end

        subgraph Output[Audio Output]
            Speaker[Device Speaker]
            Bluetooth[Bluetooth Output]
            Headphone[Wired Headphone]
        end
    end

    TransText --> AVS
    TransText --> CF
    TransText --> PV
    Voice --> AVS
    Voice --> CF
    Voice --> PV
    Settings --> AVS
    Settings --> CF

    AVS --> Queue
    CF --> Queue
    PV --> Queue

    Queue --> Pool
    Pool --> Speaker
    Pool --> Bluetooth
    Pool --> Headphone
```

---

## Data Storage Components

```mermaid
flowchart TB
    subgraph DataComponents[Data Storage System]
        subgraph Models[Data Models]
            Conv[Conversation]
            Trans[TranscriptItem]
            User[UserSettings]
            Gloss[Glossary]
            Entry[GlossaryEntry]
            VPref[VoicePreference]
        end

        subgraph Repository[Repository Pattern]
            ConvRepo[ConversationRepository]
            SetRepo[SettingsRepository]
            GlossRepo[GlossaryRepository]
        end

        subgraph Storage[Storage Backends]
            SwiftData[(SwiftData)]
            Keychain[(Keychain)]
            UserDef[(UserDefaults)]
            CloudKit[(CloudKit)]
        end

        subgraph Sync[Synchronization]
            Local[Local Changes]
            Remote[Remote Changes]
            Merge[Merge Handler]
        end
    end

    Conv --> ConvRepo
    Trans --> ConvRepo
    User --> SetRepo
    Gloss --> GlossRepo
    Entry --> GlossRepo
    VPref --> SetRepo

    ConvRepo --> SwiftData
    SetRepo --> SwiftData
    SetRepo --> UserDef
    GlossRepo --> SwiftData

    SwiftData <--> CloudKit
    Local --> Merge
    Remote --> Merge
    Merge --> SwiftData
```

---

## Authentication Components

```mermaid
flowchart TB
    subgraph AuthComponents[Authentication System]
        subgraph AppleAuth[Sign in with Apple]
            Provider[ASAuthorizationAppleIDProvider]
            Controller[ASAuthorizationController]
            Credential[ASAuthorizationAppleIDCredential]
        end

        subgraph Biometric[Biometric Auth]
            LAContext[LAContext]
            FaceID[Face ID]
            TouchID[Touch ID]
            Passcode[Fallback Passcode]
        end

        subgraph Storage[Credential Storage]
            Keychain[Keychain<br/>Secure Storage]
            SecAccess[Secure Access Control]
        end

        subgraph Session[Session Management]
            Token[Session Token]
            State[Auth State]
            Validation[State Validation]
        end
    end

    Provider --> Controller
    Controller --> Credential
    Credential --> Keychain

    LAContext --> FaceID
    LAContext --> TouchID
    LAContext --> Passcode
    FaceID --> SecAccess
    TouchID --> SecAccess

    SecAccess --> Keychain
    Keychain --> Token
    Token --> State
    State --> Validation
```

---

## Network Components

```mermaid
flowchart TB
    subgraph NetworkComponents[Network System]
        subgraph Clients[API Clients]
            CoeFont[CoeFontAPIClient]
            OpenAI[OpenAIAPIClient]
            Anthropic[AnthropicAPIClient]
            Google[GoogleSpeechClient]
        end

        subgraph Core[Core Network]
            NetMgr[NetworkManager]
            Session[URLSession]
            Monitor[NWPathMonitor]
        end

        subgraph Middleware[Middleware]
            Auth[Auth Interceptor<br/>HMAC-SHA256, Bearer]
            Retry[Retry Handler<br/>Exponential Backoff]
            RateLimit[Rate Limiter]
            Cache[Response Cache]
        end

        subgraph Security[Security Layer]
            TLS[TLS 1.3]
            Pinning[Certificate Pinning]
        end
    end

    CoeFont --> NetMgr
    OpenAI --> NetMgr
    Anthropic --> NetMgr
    Google --> NetMgr

    NetMgr --> Auth
    Auth --> Retry
    Retry --> RateLimit
    RateLimit --> Cache
    Cache --> Session

    Session --> TLS
    TLS --> Pinning
    Monitor --> NetMgr
```

---

## UI Component Hierarchy

```mermaid
flowchart TB
    subgraph UIComponents[UI Component Hierarchy]
        subgraph Root[Root]
            App[LiveLingoApp]
            Nav[NavigationStack]
        end

        subgraph Screens[Screens]
            Splash[SplashView]
            Onboard[OnboardingView]
            Home[HomeView]
            Interp[InterpretationView]
            History[HistoryView]
            Settings[SettingsView]
            Dict[DictionaryView]
        end

        subgraph Shared[Shared Components]
            LangPicker[LanguagePairPicker]
            VoiceSel[VoiceSelector]
            TransCard[TranscriptCard]
            PermReq[PermissionRequestView]
            ErrorBanner[ErrorBanner]
            Loading[LoadingIndicator]
        end

        subgraph Interpretation[Interpretation Components]
            Waveform[WaveformVisualizer]
            SpeakerInd[SpeakerIndicator]
            TransList[TranscriptListView]
            Controls[ControlBar]
        end
    end

    App --> Nav
    Nav --> Splash
    Nav --> Onboard
    Nav --> Home
    Nav --> Interp
    Nav --> History
    Nav --> Settings
    Nav --> Dict

    Home --> LangPicker
    Interp --> Waveform
    Interp --> SpeakerInd
    Interp --> TransList
    Interp --> Controls
    TransList --> TransCard
    Settings --> VoiceSel
```

---

## Component Dependencies Matrix

```mermaid
flowchart LR
    subgraph Independent[Independent Components]
        KeyMgr[KeychainManager]
        NetMon[NetworkMonitor]
        Cache[TranslationCache]
        Buffer[AudioBufferPool]
    end

    subgraph Dependent[Dependent Components]
        AuthMgr[AuthManager<br/>-> KeychainManager]
        NetMgr[NetworkManager<br/>-> NetworkMonitor]
        TransMgr[TranslationManager<br/>-> Cache, NetworkManager]
        AudioMgr[AudioSessionManager<br/>-> AudioBufferPool]
    end

    subgraph Composite[Composite Components]
        InterpVM[InterpretationViewModel<br/>-> STT, Trans, TTS, Audio]
    end

    KeyMgr --> AuthMgr
    NetMon --> NetMgr
    Cache --> TransMgr
    NetMgr --> TransMgr
    Buffer --> AudioMgr

    AuthMgr --> InterpVM
    TransMgr --> InterpVM
    AudioMgr --> InterpVM
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
