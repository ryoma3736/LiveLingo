# LiveLingo - App Lifecycle Workflows

## WF-LIFE-001: Cold Start

App launch from terminated state.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant App as LiveLingoApp
    participant Scene as SceneDelegate
    participant DI as DependencyContainer
    participant Auth as AuthManager
    participant Perm as PermissionManager
    participant Nav as NavigationController

    System->>App: application(_:didFinishLaunching:)
    App->>DI: initialize()
    DI->>DI: registerServices()

    par Parallel Initialization
        DI->>Auth: checkAuthenticationState()
        and
        DI->>Perm: checkAllPermissions()
    end

    System->>Scene: scene(_:willConnectTo:)
    Scene->>Nav: setupRootViewController()

    alt First Launch
        Nav->>Nav: showOnboarding()
    else Returning User
        Nav->>Nav: showHome()
    end

    App->>App: configureAudioSession()
    App->>App: loadUserSettings()
    App->>App: setupNotificationHandlers()

    App-->>System: launch complete
```

---

## WF-LIFE-002: Warm Start (Resume from Background)

App resume from suspended state.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant Scene as SceneDelegate
    participant Audio as AudioSessionManager
    participant STT as SpeechRecognitionManager
    participant Net as NetworkManager

    System->>Scene: sceneWillEnterForeground(_:)

    Scene->>Audio: reactivateSession()
    Audio->>Audio: try session.setActive(true)
    Audio-->>Scene: activated

    Scene->>Net: checkConnectivity()
    Net-->>Scene: isOnline: true

    alt Was Interpreting
        Scene->>STT: resumeRecognition()
        STT->>STT: reinstallAudioTap()
        STT-->>Scene: recognition resumed
        Note over Scene: Continue from where left off
    end

    Scene->>Scene: refreshUI()

    System->>Scene: sceneDidBecomeActive(_:)
    Scene-->>System: fully active
```

---

## WF-LIFE-003: First Launch (Onboarding)

Initial setup and permission request flow.

```mermaid
sequenceDiagram
    participant User
    participant OB as OnboardingView
    participant Perm as PermissionManager
    participant Lang as LanguageManager
    participant Store as UserDefaults

    OB->>User: Show Welcome Screen
    User->>OB: Tap Continue

    OB->>User: Show Feature Introduction
    User->>OB: Swipe through pages

    OB->>User: Request Microphone Permission
    OB->>Perm: requestMicrophonePermission()
    Perm->>Perm: AVAudioSession.requestRecordPermission

    alt Permission Granted
        Perm-->>OB: granted: true
        OB->>OB: showNextStep()
    else Permission Denied
        Perm-->>OB: granted: false
        OB->>User: Show Permission Required Alert
        User->>OB: Open Settings / Skip
    end

    OB->>User: Request Speech Recognition Permission
    OB->>Perm: requestSpeechRecognitionPermission()
    Perm->>Perm: SFSpeechRecognizer.requestAuthorization
    Perm-->>OB: status

    OB->>User: Select Languages
    User->>Lang: setLanguagePair(ja, en)
    Lang->>Store: saveLastPair()

    OB->>User: Select App UI Language
    User->>Lang: setAppLanguage(ja/en/zh)

    OB->>Store: set("onboarding_complete", true)
    OB->>OB: navigateToHome()
```

---

## WF-LIFE-004: Background Transition

App enters background during active interpretation.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant Scene as SceneDelegate
    participant BG as BackgroundAudioManager
    participant Audio as AudioSessionManager
    participant STT as SpeechRecognitionManager
    participant Data as DataManager

    System->>Scene: sceneWillResignActive(_:)
    Scene->>Scene: prepareForBackground()

    System->>Scene: sceneDidEnterBackground(_:)

    alt Interpretation Active
        Scene->>BG: beginBackgroundTask()
        BG->>BG: UIApplication.beginBackgroundTask

        Scene->>STT: pauseRecognition()
        Note over STT: iOS does not support background STT

        Scene->>Audio: continueRecording()
        Note over Audio: Audio recording can continue

        Scene->>Data: saveInProgressConversation()
    else No Active Interpretation
        Scene->>Audio: deactivateSession()
    end

    Scene->>Scene: scheduleBackgroundRefresh()
    Scene-->>System: background transition complete
```

---

## WF-LIFE-005: Foreground Transition

App returns to foreground with pending work.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant Scene as SceneDelegate
    participant BG as BackgroundAudioManager
    participant Audio as AudioSessionManager
    participant STT as SpeechRecognitionManager
    participant Proc as BufferedAudioProcessor

    System->>Scene: sceneWillEnterForeground(_:)

    Scene->>BG: endBackgroundTask()

    Scene->>Audio: reactivateSession()
    Audio-->>Scene: activated

    alt Has Buffered Audio
        Scene->>Proc: processBufferedAudio()
        Proc->>STT: recognize(bufferedAudioData)
        STT-->>Proc: transcribedText
        Proc->>Proc: queueForTranslation()
    end

    Scene->>STT: resumeRecognition()
    STT-->>Scene: recognition active

    System->>Scene: sceneDidBecomeActive(_:)
    Scene->>Scene: updateUI()
```

---

## WF-LIFE-006: App Termination

Graceful shutdown with data persistence.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant App as AppDelegate
    participant Audio as AudioSessionManager
    participant STT as SpeechRecognitionManager
    participant Data as DataManager
    participant Cache as CacheManager

    System->>App: applicationWillTerminate(_:)

    App->>STT: forceStop()
    STT->>STT: cancelAllTasks()

    App->>Audio: deactivateSession()
    Audio->>Audio: session.setActive(false)

    App->>Data: saveAllPendingChanges()
    Data->>Data: modelContext.save()

    App->>Cache: persistImportantCaches()
    Cache->>Cache: writeToDisk()

    App->>App: clearTemporaryFiles()

    App-->>System: termination complete
```

---

## App State Diagram

```mermaid
stateDiagram-v2
    [*] --> NotRunning

    NotRunning --> Launching: User taps app icon
    Launching --> InactiveFirstLaunch: First launch
    Launching --> InactiveReturning: Returning user

    InactiveFirstLaunch --> Onboarding: Show onboarding
    Onboarding --> Active: Complete onboarding

    InactiveReturning --> Active: Resume

    Active --> Inactive: Interruption / Home button
    Inactive --> Active: Return to app
    Inactive --> Background: App suspended

    Background --> Inactive: User returns
    Background --> Suspended: System suspends

    Suspended --> Inactive: User returns
    Suspended --> NotRunning: System terminates

    Active --> NotRunning: User force quit
    Background --> NotRunning: System terminates
```

---

## Memory Warning Response

```mermaid
sequenceDiagram
    participant System as iOS System
    participant App as AppDelegate
    participant Mem as MemoryManager
    participant Cache as TranslationCache
    participant Pool as AudioBufferPool
    participant History as ConversationHistory

    System->>App: didReceiveMemoryWarning()
    App->>Mem: handleMemoryWarning()

    Mem->>Mem: checkMemoryUsage()

    alt Usage > 92% (Critical)
        Mem->>Cache: clearAll()
        Mem->>Pool: releaseAll()
        Mem->>History: keepOnly(last: 5)
        Note over Mem: Force garbage collection
    else Usage > 75% (Warning)
        Mem->>Cache: trimOldEntries(keepPercent: 0.5)
        Mem->>Pool: releaseExcess()
    end

    Mem-->>App: cleanup complete
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
