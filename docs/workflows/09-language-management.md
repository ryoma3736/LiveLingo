# LiveLingo - Language Management Workflows

## WF-LNG-001: Language Pair Selection

Source and target language setup.

```mermaid
sequenceDiagram
    participant User
    participant UI as LanguageSelectionView
    participant LM as LanguageManager
    participant Store as UserDefaults
    participant STT as SpeechRecognitionManager
    participant TTS as TTSManager

    User->>UI: Open Language Selection

    UI->>LM: getAvailableLanguages()
    LM-->>UI: [ja-JP, en-US, zh-CN, ko-KR, ...]

    UI->>UI: groupByCategory()
    Note over UI: Recent, All Languages

    UI->>User: Display Language List

    User->>UI: Select Source: ja-JP
    User->>UI: Select Target: en-US

    UI->>LM: setLanguagePair(source: ja-JP, target: en-US)
    LM->>LM: currentPair = LanguagePair(ja-JP, en-US)

    par Update Components
        LM->>Store: saveLastPair(currentPair)
        and
        LM->>STT: updateRecognitionLanguage(ja-JP)
        and
        LM->>TTS: updateSpeechLanguage(en-US)
    end

    LM-->>UI: languagePairUpdated
    UI->>UI: updateUI(source: ja-JP, target: en-US)
```

---

## WF-LNG-002: Language Swap

Quick switch between source and target.

```mermaid
sequenceDiagram
    participant User
    participant UI as LanguageToggleView
    participant LM as LanguageManager
    participant STT as SpeechRecognitionManager
    participant TTS as TTSManager
    participant Anim as SwiftUI Animation

    User->>UI: Tap Swap Button

    UI->>Anim: withAnimation(.spring())

    UI->>LM: swapLanguages()

    LM->>LM: temp = currentPair.source
    LM->>LM: currentPair.source = currentPair.target
    LM->>LM: currentPair.target = temp

    par Parallel Updates
        LM->>STT: updateRecognitionLanguage(newSource)
        STT->>STT: reinitializeRecognizer()
        and
        LM->>TTS: updateSpeechLanguage(newTarget)
        TTS->>TTS: updateVoice()
    end

    LM->>LM: saveLastPair()
    LM-->>UI: languagesSwapped

    UI->>Anim: animate swap icons
    Note over Anim: Rotate arrows 180 degrees
```

---

## WF-LNG-003: Language Pack Download

Offline model installation for translation.

```mermaid
sequenceDiagram
    participant User
    participant UI as LanguagePacksView
    participant LM as LanguageManager
    participant Avail as LanguageAvailability
    participant Trans as TranslationSession
    participant Notif as DownloadNotification

    User->>UI: View Language Packs

    UI->>LM: checkLanguagePackAvailability()
    LM->>Avail: LanguageAvailability()

    loop For each language
        LM->>Avail: status(from: source, to: lang)
        Avail-->>LM: downloadStatus
    end

    LM-->>UI: [LanguagePack]
    UI->>UI: displayPackList()

    User->>UI: Tap Download (French)

    UI->>LM: downloadLanguagePack(fr-FR)
    LM->>LM: updatePackStatus(.downloading(0))

    LM->>Trans: TranslationSession(config)
    Note over Trans: This triggers download

    loop Download Progress
        Trans-->>LM: progress updates
        LM->>UI: updateProgress(percent)
        UI->>UI: updateProgressBar()
    end

    Trans-->>LM: download complete
    LM->>LM: updatePackStatus(.downloaded)
    LM->>Notif: showDownloadComplete("French")

    LM-->>UI: packDownloaded
    UI->>UI: showCheckmark()
```

---

## WF-LNG-004: App UI Language Switch

Change UI language (Japanese/English/Chinese).

```mermaid
sequenceDiagram
    participant User
    participant UI as SettingsView
    participant ALM as AppLanguageManager
    participant UD as UserDefaults
    participant Bundle as Bundle
    participant Root as RootView

    User->>UI: Open Language Settings

    UI->>ALM: getCurrentLanguage()
    ALM-->>UI: currentLanguage: ja

    UI->>User: Display Language Options
    Note over UI: Japanese (selected)<br/>English<br/>Chinese

    User->>UI: Select English

    UI->>ALM: setAppLanguage(.english)

    ALM->>UD: set(["en"], forKey: "AppleLanguages")
    ALM->>UD: synchronize()

    ALM->>ALM: currentLanguage = .english

    ALM-->>UI: languageChanged

    UI->>UI: showRestartAlert()
    Note over UI: "App language will change<br/>after restart"

    alt Immediate Effect Desired
        UI->>Root: forceUIRefresh()
        Root->>Bundle: localizedBundle(for: "en")
        Root->>Root: recreateViewHierarchy()
    else Wait for Restart
        Note over UI: Changes apply on next launch
    end
```

---

## WF-LNG-005: Language Preference Persistence

Save and restore user language preferences.

```mermaid
sequenceDiagram
    participant App as Application
    participant LM as LanguageManager
    participant Storage as LanguageStorage
    participant UD as UserDefaults
    participant Cloud as iCloudKV

    Note over App: App Launch

    App->>LM: initialize()
    LM->>Storage: loadLastPair()

    Storage->>UD: object(forKey: "lastLanguagePair")

    alt Local Data Exists
        UD-->>Storage: encodedPair
        Storage->>Storage: decode(LanguagePair.self)
        Storage-->>LM: LanguagePair(ja-JP, en-US)
    else No Local Data
        Storage->>Cloud: getValue("lastLanguagePair")

        alt Cloud Data Exists
            Cloud-->>Storage: cloudPair
            Storage-->>LM: cloudPair
        else No Cloud Data
            Storage-->>LM: LanguagePair.default (ja-JP, en-US)
        end
    end

    LM->>LM: currentPair = loadedPair

    Note over App: User Changes Language

    LM->>Storage: saveLastPair(newPair)

    par Save to Multiple Stores
        Storage->>UD: set(encodedPair, forKey: "lastLanguagePair")
        and
        Storage->>Cloud: setValue(encodedPair, forKey: "lastLanguagePair")
    end

    Storage-->>LM: saved
```

---

## Supported Languages Matrix

```mermaid
flowchart TD
    subgraph Phase1[Phase 1 - Launch]
        JA[Japanese ja-JP]
        EN_US[English US en-US]
        EN_GB[English UK en-GB]
        ZH_CN[Chinese Simplified zh-CN]
        ZH_TW[Chinese Traditional zh-TW]
        KO[Korean ko-KR]
    end

    subgraph Phase2[Phase 2 - Post-Launch]
        FR[French fr-FR]
        ES_ES[Spanish Spain es-ES]
        ES_MX[Spanish Mexico es-MX]
        VI[Vietnamese vi-VN]
        PT[Portuguese Brazil pt-BR]
    end

    subgraph Capabilities
        STT[Speech Recognition]
        TRN[Translation]
        TTS[Text-to-Speech]
        OFF[Offline Support]
    end

    JA --> STT
    JA --> TRN
    JA --> TTS
    JA --> OFF

    EN_US --> STT
    EN_US --> TRN
    EN_US --> TTS
    EN_US --> OFF

    ZH_CN --> STT
    ZH_CN --> TRN
    ZH_CN --> TTS

    VI --> STT
    VI --> TRN
    VI --> TTS
    Note over VI: No offline support
```

---

## Language Detection Flow

```mermaid
sequenceDiagram
    participant Audio as AudioInput
    participant Detect as LanguageDetector
    participant Recog as MultiRecognizer
    participant LM as LanguageManager
    participant UI as LanguageIndicator

    Audio->>Detect: audioBuffer (2 seconds)

    Detect->>Detect: checkAutoDetectEnabled()

    alt Auto-Detect Enabled
        par Parallel Recognition
            Detect->>Recog: recognize(buffer, locale: ja-JP)
            Recog-->>Detect: {confidence: 0.92}
            and
            Detect->>Recog: recognize(buffer, locale: en-US)
            Recog-->>Detect: {confidence: 0.45}
            and
            Detect->>Recog: recognize(buffer, locale: zh-CN)
            Recog-->>Detect: {confidence: 0.30}
        end

        Detect->>Detect: selectHighestConfidence()
        Note over Detect: ja-JP with 92% confidence

        alt Confidence >= 80%
            Detect->>LM: setSourceLanguage(ja-JP)
            LM-->>UI: updateLanguageIndicator(ja-JP)
            Detect-->>Audio: proceed with ja-JP
        else Low Confidence
            Detect->>UI: showLanguageSelectionPrompt()
        end
    else Manual Selection
        Note over Detect: Use user-selected language
    end
```

---

## Language State Diagram

```mermaid
stateDiagram-v2
    [*] --> Loading

    Loading --> DefaultPair: no saved preference
    Loading --> RestoredPair: preference loaded

    DefaultPair --> Active: ja-JP to en-US
    RestoredPair --> Active: restored pair

    Active --> Selecting: user opens language menu
    Selecting --> Active: selection confirmed
    Selecting --> Active: cancelled

    Active --> Swapping: user taps swap
    Swapping --> Active: languages swapped

    Active --> Downloading: language pack needed
    Downloading --> Active: download complete
    Downloading --> Active: download failed (fallback)

    Active --> Detecting: auto-detect speech
    Detecting --> Active: language detected
    Detecting --> Selecting: low confidence
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
