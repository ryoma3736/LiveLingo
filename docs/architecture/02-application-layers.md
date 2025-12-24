# LiveLingo - Application Layer Architecture

## Clean Architecture + MVVM Overview

```mermaid
flowchart TB
    subgraph Presentation[Presentation Layer]
        direction TB
        Views[SwiftUI Views<br/>InterpretationView, HomeView, SettingsView]
        ViewModels[ViewModels<br/>InterpretationViewModel, HistoryViewModel]

        Views <-->|Binding| ViewModels
    end

    subgraph Domain[Domain Layer]
        direction TB
        UseCases[Use Cases<br/>StartInterpretationUseCase<br/>TranslateTextUseCase<br/>SaveConversationUseCase]
        Entities[Entities<br/>Conversation, TranscriptItem<br/>LanguagePair, Voice]
        Protocols[Protocols<br/>SpeechRecognizable<br/>Translatable<br/>Synthesizable]
    end

    subgraph Data[Data Layer]
        direction TB
        Repositories[Repositories<br/>ConversationRepository<br/>SettingsRepository<br/>GlossaryRepository]
        DataSources[Data Sources<br/>SwiftDataSource<br/>KeychainDataSource<br/>CloudKitDataSource]
        APIClients[API Clients<br/>CoeFontClient<br/>OpenAIClient<br/>AnthropicClient]
    end

    subgraph Infrastructure[Infrastructure Layer]
        direction TB
        Frameworks[iOS Frameworks<br/>SFSpeechRecognizer<br/>AVSpeechSynthesizer<br/>AVAudioSession]
        Storage[Storage<br/>SwiftData, Keychain<br/>UserDefaults]
        Network[Network<br/>URLSession<br/>NetworkMonitor]
    end

    ViewModels --> UseCases
    UseCases --> Entities
    UseCases --> Protocols
    Protocols -.->|Implemented by| Repositories
    Repositories --> DataSources
    Repositories --> APIClients
    DataSources --> Storage
    APIClients --> Network
    Repositories --> Frameworks
```

---

## MVVM Pattern Detail

```mermaid
flowchart LR
    subgraph View[View Layer - SwiftUI]
        V1[InterpretationView]
        V2[HomeView]
        V3[HistoryView]
        V4[SettingsView]
    end

    subgraph ViewModel[ViewModel Layer]
        VM1[InterpretationViewModel<br/>@Published state<br/>@Published transcripts]
        VM2[HomeViewModel<br/>@Published languages]
        VM3[HistoryViewModel<br/>@Published conversations]
        VM4[SettingsViewModel<br/>@Published preferences]
    end

    subgraph Model[Model Layer]
        M1[SpeechRecognitionManager]
        M2[TranslationManager]
        M3[TTSManager]
        M4[ConversationRepository]
    end

    V1 <-->|ObservedObject| VM1
    V2 <-->|ObservedObject| VM2
    V3 <-->|ObservedObject| VM3
    V4 <-->|ObservedObject| VM4

    VM1 --> M1
    VM1 --> M2
    VM1 --> M3
    VM1 --> M4
```

---

## Dependency Injection Architecture

```mermaid
flowchart TB
    subgraph Container[DependencyContainer]
        Register[Service Registration]
        Resolve[Service Resolution]
    end

    subgraph Services[Registered Services]
        Auth[AuthManager]
        Speech[SpeechRecognitionManager]
        Trans[TranslationManager]
        TTS[TTSManager]
        Audio[AudioSessionManager]
        Data[DataManager]
        Net[NetworkManager]
        Perm[PermissionManager]
    end

    subgraph Consumers[Service Consumers]
        VMs[ViewModels]
        UCs[Use Cases]
    end

    Container -->|Singleton| Auth
    Container -->|Singleton| Speech
    Container -->|Singleton| Trans
    Container -->|Singleton| TTS
    Container -->|Singleton| Audio
    Container -->|Singleton| Data
    Container -->|Singleton| Net
    Container -->|Singleton| Perm

    VMs -->|@Injected| Container
    UCs -->|@Injected| Container
```

---

## Layer Responsibilities

```mermaid
flowchart TB
    subgraph PresentationResp[Presentation Layer Responsibilities]
        P1[UI Rendering]
        P2[User Input Handling]
        P3[State Binding]
        P4[Navigation]
        P5[Animations]
    end

    subgraph DomainResp[Domain Layer Responsibilities]
        D1[Business Logic]
        D2[Validation]
        D3[Entity Definitions]
        D4[Protocol Definitions]
        D5[Use Case Orchestration]
    end

    subgraph DataResp[Data Layer Responsibilities]
        DA1[Data Persistence]
        DA2[API Communication]
        DA3[Data Transformation]
        DA4[Caching]
        DA5[Error Handling]
    end

    subgraph InfraResp[Infrastructure Responsibilities]
        I1[Framework Integration]
        I2[Network Management]
        I3[Storage Management]
        I4[Security Implementation]
    end

    PresentationResp --> DomainResp
    DomainResp --> DataResp
    DataResp --> InfraResp
```

---

## Module Structure

```mermaid
flowchart TB
    subgraph App[LiveLingo App]
        subgraph Features[Feature Modules]
            Interpretation[Interpretation<br/>Main translation feature]
            History[History<br/>Past conversations]
            Settings[Settings<br/>User preferences]
            Dictionary[Dictionary<br/>Custom glossary]
            Onboarding[Onboarding<br/>First-time setup]
        end

        subgraph Core[Core Modules]
            Audio[Audio<br/>Session management]
            Speech[Speech<br/>Recognition]
            Translation[Translation<br/>Text translation]
            Synthesis[Synthesis<br/>TTS]
            Security[Security<br/>Auth & encryption]
        end

        subgraph Shared[Shared Modules]
            UI[UI Components<br/>Reusable views]
            Utils[Utilities<br/>Extensions, helpers]
            Networking[Networking<br/>API clients]
            Persistence[Persistence<br/>Data storage]
        end
    end

    Features --> Core
    Features --> Shared
    Core --> Shared
```

---

## Protocol-Oriented Design

```mermaid
classDiagram
    class SpeechRecognizable {
        <<protocol>>
        +startRecognition(locale: Locale)
        +stopRecognition()
        +partialResults: AsyncStream~String~
        +finalResults: AsyncStream~String~
    }

    class Translatable {
        <<protocol>>
        +translate(text: String, from: Locale, to: Locale) async throws -> String
        +translateStream(tokens: AsyncStream~String~) -> AsyncStream~String~
    }

    class Synthesizable {
        <<protocol>>
        +speak(text: String, voice: Voice) async throws
        +stop()
        +isSpeaking: Bool
    }

    class SFSpeechManager {
        +startRecognition(locale: Locale)
        +stopRecognition()
    }

    class WhisperKitManager {
        +startRecognition(locale: Locale)
        +stopRecognition()
    }

    class AppleTranslationManager {
        +translate(text: String, from: Locale, to: Locale)
    }

    class LLMTranslationManager {
        +translate(text: String, from: Locale, to: Locale)
    }

    class AVSpeechManager {
        +speak(text: String, voice: Voice)
    }

    class CoeFontManager {
        +speak(text: String, voice: Voice)
    }

    SpeechRecognizable <|.. SFSpeechManager
    SpeechRecognizable <|.. WhisperKitManager
    Translatable <|.. AppleTranslationManager
    Translatable <|.. LLMTranslationManager
    Synthesizable <|.. AVSpeechManager
    Synthesizable <|.. CoeFontManager
```

---

## Data Flow Between Layers

```mermaid
flowchart LR
    subgraph UI[UI Layer]
        View[SwiftUI View]
    end

    subgraph VM[ViewModel Layer]
        ViewModel[ViewModel<br/>@MainActor]
    end

    subgraph UseCase[Use Case Layer]
        UC[Use Case]
    end

    subgraph Repo[Repository Layer]
        Repository[Repository]
    end

    subgraph DS[Data Source Layer]
        Local[Local Data Source]
        Remote[Remote Data Source]
    end

    View -->|User Action| ViewModel
    ViewModel -->|Execute| UC
    UC -->|Fetch/Save| Repository
    Repository -->|Read/Write| Local
    Repository -->|API Call| Remote

    Remote -->|Response| Repository
    Local -->|Data| Repository
    Repository -->|Entity| UC
    UC -->|Result| ViewModel
    ViewModel -->|@Published| View
```

---

## Error Handling Flow

```mermaid
flowchart TB
    subgraph Source[Error Sources]
        Network[Network Errors]
        API[API Errors]
        Storage[Storage Errors]
        Framework[Framework Errors]
    end

    subgraph Mapping[Error Mapping]
        Mapper[Error Mapper]
    end

    subgraph AppError[App Error Types]
        E1[NetworkError]
        E2[TranslationError]
        E3[SpeechError]
        E4[StorageError]
        E5[AuthError]
    end

    subgraph Handling[Error Handling]
        Handler[Error Handler]
        UI[Error UI]
        Retry[Retry Logic]
        Fallback[Fallback Strategy]
    end

    Network --> Mapper
    API --> Mapper
    Storage --> Mapper
    Framework --> Mapper

    Mapper --> E1
    Mapper --> E2
    Mapper --> E3
    Mapper --> E4
    Mapper --> E5

    E1 --> Handler
    E2 --> Handler
    E3 --> Handler
    E4 --> Handler
    E5 --> Handler

    Handler --> UI
    Handler --> Retry
    Handler --> Fallback
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
