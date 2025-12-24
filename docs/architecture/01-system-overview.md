# LiveLingo - System Overview Architecture

## C4 Context Diagram

High-level view of the LiveLingo system and its external actors.

```mermaid
C4Context
    title LiveLingo System Context Diagram

    Person(user, "User", "Person who needs real-time interpretation")

    System(livelingo, "LiveLingo", "iOS Application providing real-time speech interpretation")

    System_Ext(apple_stt, "Apple SFSpeechRecognizer", "On-device speech recognition")
    System_Ext(apple_trans, "Apple Translation", "On-device translation framework")
    System_Ext(apple_tts, "AVSpeechSynthesizer", "System text-to-speech")
    System_Ext(apple_auth, "Sign in with Apple", "Authentication service")

    System_Ext(openai, "OpenAI API", "GPT-4o-mini for cloud translation")
    System_Ext(anthropic, "Anthropic API", "Claude-3-haiku for cloud translation")
    System_Ext(coefont, "CoeFont API", "AI voice synthesis service")
    System_Ext(google_speech, "Google Live Speech", "Cloud speech recognition")

    System_Ext(icloud, "iCloud/CloudKit", "Cross-device data synchronization")

    Rel(user, livelingo, "Uses", "Touch/Voice")

    Rel(livelingo, apple_stt, "Recognizes speech", "SFSpeechRecognizer")
    Rel(livelingo, apple_trans, "Translates text", "Translation Framework")
    Rel(livelingo, apple_tts, "Synthesizes speech", "AVFoundation")
    Rel(livelingo, apple_auth, "Authenticates", "AuthenticationServices")

    Rel(livelingo, openai, "Translates text", "HTTPS/REST")
    Rel(livelingo, anthropic, "Translates text", "HTTPS/REST")
    Rel(livelingo, coefont, "Synthesizes voice", "HTTPS/REST + HMAC-SHA256")
    Rel(livelingo, google_speech, "Recognizes speech", "HTTPS/REST")

    Rel(livelingo, icloud, "Syncs data", "CloudKit")
```

---

## C4 Container Diagram

Application containers and their responsibilities.

```mermaid
flowchart TB
    subgraph UserDevice[iOS Device]
        subgraph LiveLingoApp[LiveLingo Application]
            UI[SwiftUI Layer<br/>Views, ViewModels]
            Domain[Domain Layer<br/>Use Cases, Entities]
            Data[Data Layer<br/>Repositories, APIs]

            UI --> Domain
            Domain --> Data
        end

        subgraph iOSFrameworks[iOS Frameworks]
            SF[SFSpeechRecognizer]
            AVS[AVSpeechSynthesizer]
            Trans[Translation Framework]
            Audio[AVAudioSession]
            KC[Keychain]
            SD[SwiftData]
        end

        Data --> SF
        Data --> AVS
        Data --> Trans
        Data --> Audio
        Data --> KC
        Data --> SD
    end

    subgraph ExternalServices[External Services]
        OAI[OpenAI API]
        ANT[Anthropic API]
        CF[CoeFont API]
        GS[Google Speech API]
    end

    subgraph CloudStorage[Cloud Storage]
        CK[CloudKit/iCloud]
    end

    Data --> OAI
    Data --> ANT
    Data --> CF
    Data --> GS
    Data --> CK
```

---

## System Boundary Diagram

```mermaid
flowchart LR
    subgraph Trust[Trust Boundary - Device]
        subgraph App[LiveLingo App]
            Presentation[Presentation Layer]
            Business[Business Logic]
            DataAccess[Data Access]
        end

        subgraph Secure[Secure Enclave]
            Biometric[Face ID / Touch ID]
            Keys[Encryption Keys]
        end

        subgraph Storage[Local Storage]
            SwiftData[(SwiftData)]
            Keychain[(Keychain)]
            UserDefaults[(UserDefaults)]
        end
    end

    subgraph Untrust[Untrusted - Network]
        Apple[Apple Services]
        Cloud[Cloud APIs]
        Internet((Internet))
    end

    DataAccess -->|Encrypted| SwiftData
    DataAccess -->|Secure| Keychain
    DataAccess -->|Preferences| UserDefaults

    Business -->|Biometric Auth| Biometric
    DataAccess -->|Key Storage| Keys

    DataAccess -->|TLS 1.3| Internet
    Internet --> Apple
    Internet --> Cloud
```

---

## Deployment View

```mermaid
flowchart TB
    subgraph Devices[User Devices]
        iPhone[iPhone<br/>iOS 17+]
        iPad[iPad<br/>iPadOS 17+]
    end

    subgraph AppleInfra[Apple Infrastructure]
        AppStore[App Store<br/>Distribution]
        iCloudSync[iCloud<br/>Data Sync]
        APNS[APNs<br/>Push Notifications]
        SiriKit[SiriKit<br/>Voice Control]
    end

    subgraph CloudProviders[Cloud Providers]
        subgraph OpenAICloud[OpenAI]
            GPT4[GPT-4o-mini<br/>Translation]
        end

        subgraph AnthropicCloud[Anthropic]
            Claude[Claude-3-haiku<br/>Translation]
        end

        subgraph CoeFontCloud[CoeFont]
            VoiceSynth[AI Voice<br/>Synthesis]
        end

        subgraph GoogleCloud[Google Cloud]
            LiveSpeech[Live Speech<br/>Recognition]
        end
    end

    iPhone --> AppStore
    iPad --> AppStore

    iPhone <--> iCloudSync
    iPad <--> iCloudSync

    iPhone --> GPT4
    iPhone --> Claude
    iPhone --> VoiceSynth
    iPhone --> LiveSpeech
```

---

## Technology Stack Overview

```mermaid
flowchart TB
    subgraph Frontend[Frontend Layer]
        SwiftUI[SwiftUI<br/>Declarative UI]
        Combine[Combine<br/>Reactive Streams]
    end

    subgraph Logic[Business Logic Layer]
        ViewModels[ViewModels<br/>State Management]
        UseCases[Use Cases<br/>Business Rules]
        Managers[Managers<br/>Service Coordination]
    end

    subgraph DataLayer[Data Layer]
        Repos[Repositories<br/>Data Abstraction]
        APIs[API Clients<br/>Network Calls]
        Cache[Cache<br/>Performance]
    end

    subgraph Persistence[Persistence Layer]
        SwiftData[(SwiftData<br/>Core Data)]
        Keychain[(Keychain<br/>Secrets)]
        UserDef[(UserDefaults<br/>Preferences)]
    end

    subgraph iOS[iOS Frameworks]
        Speech[Speech Framework]
        AVFoundation[AVFoundation]
        Translation[Translation]
        Security[Security Framework]
    end

    Frontend --> Logic
    Logic --> DataLayer
    DataLayer --> Persistence
    DataLayer --> iOS
```

---

## Actor Interactions

```mermaid
flowchart LR
    subgraph Actors
        Speaker1[Speaker 1<br/>Japanese]
        Speaker2[Speaker 2<br/>English]
    end

    subgraph LiveLingo[LiveLingo App]
        Mic[Microphone<br/>Input]
        STT[Speech-to-Text<br/>Recognition]
        Trans[Translation<br/>Engine]
        TTS[Text-to-Speech<br/>Synthesis]
        Spk[Speaker<br/>Output]
    end

    Speaker1 -->|Speaks Japanese| Mic
    Mic --> STT
    STT -->|Japanese Text| Trans
    Trans -->|English Text| TTS
    TTS --> Spk
    Spk -->|Plays English| Speaker2

    Speaker2 -->|Speaks English| Mic
    Mic --> STT
    STT -->|English Text| Trans
    Trans -->|Japanese Text| TTS
    TTS --> Spk
    Spk -->|Plays Japanese| Speaker1
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
