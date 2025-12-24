# LiveLingo - Error Handling Workflows

## WF-ERR-001: Network Error Recovery

Offline and timeout handling with retry.

```mermaid
sequenceDiagram
    participant User
    participant UI as InterpretationView
    participant VM as ViewModel
    participant Net as NetworkManager
    participant API as External API
    participant Retry as RetryHandler
    participant Fallback as FallbackManager

    VM->>Net: execute(request)
    Net->>API: HTTP Request

    alt Timeout
        API--xNet: timeout
        Net->>Retry: shouldRetry(timeout, attempt: 1)
        Retry-->>Net: true

        loop Retry with backoff
            Net->>API: retry request
            alt Success
                API-->>Net: response
                Net-->>VM: success
            else Still Failing
                API--xNet: error
                Retry->>Retry: calculateNextDelay()
            end
        end

        alt Max Retries Exhausted
            Retry-->>Net: false
            Net-->>VM: throw NetworkError.timeout
        end
    else Offline
        Net->>Net: checkConnectivity()
        Net-->>VM: throw NetworkError.offline

        VM->>UI: showOfflineBanner()
        UI->>User: "No internet connection"

        VM->>Fallback: handleOffline()
        Fallback->>Fallback: checkLocalAlternatives()

        alt Can Use Offline Translation
            Fallback->>VM: useOfflineTranslation()
            VM->>UI: "Using offline mode"
        else No Offline Support
            Fallback->>VM: queueForLater()
            VM->>UI: "Will sync when online"
        end
    end
```

---

## WF-ERR-002: STT Error Recovery

Speech recognition failure handling.

```mermaid
sequenceDiagram
    participant User
    participant STT as SpeechRecognitionManager
    participant Engine as AVAudioEngine
    participant Recognizer as SFSpeechRecognizer
    participant Fallback as WhisperKit
    participant UI as ErrorIndicator

    STT->>Engine: startRecording()
    Engine->>Recognizer: process audio

    alt Recognition Error
        Recognizer--xSTT: error

        STT->>STT: categorizeError()

        alt Audio Input Error
            STT->>Engine: reinstallAudioTap()
            Engine-->>STT: tap reinstalled
            STT->>STT: retryRecognition()
        else Recognizer Unavailable
            STT->>UI: showTemporaryMessage("Reconnecting...")
            STT->>Recognizer: reinitialize()

            alt Reinitialization Success
                Recognizer-->>STT: available
                STT->>STT: resumeRecognition()
                STT->>UI: hideMessage()
            else Still Unavailable
                STT->>Fallback: activate()
                Fallback-->>STT: ready
                STT->>UI: "Using offline recognition"
            end
        else Rate Limited
            STT->>STT: wait(1 minute)
            STT->>UI: showCooldownTimer()
        else Permission Revoked
            STT->>UI: showPermissionRequired()
            UI->>User: "Permission needed"
        end
    else Audio Session Interrupted
        STT->>STT: pauseRecognition()
        Note over STT: Wait for interruption end
    end
```

---

## WF-ERR-003: API Error Display

User-friendly error messages.

```mermaid
sequenceDiagram
    participant API as APIClient
    participant Handler as ErrorHandler
    participant Mapper as ErrorMessageMapper
    participant UI as ErrorView
    participant User

    API-->>Handler: throw error

    Handler->>Handler: identifyErrorType()

    alt NetworkError
        Handler->>Mapper: mapNetworkError(error)
        Mapper->>Mapper: selectMessage()

        alt offline
            Mapper-->>Handler: "No internet connection.<br/>Please check your network."
        else timeout
            Mapper-->>Handler: "Request timed out.<br/>Please try again."
        else rateLimited
            Mapper-->>Handler: "Too many requests.<br/>Please wait a moment."
        else serverError
            Mapper-->>Handler: "Service temporarily unavailable.<br/>Please try again later."
        end
    else CoeFontError
        Handler->>Mapper: mapCoeFontError(error)
        Mapper-->>Handler: localized message
    else TranslationError
        Handler->>Mapper: mapTranslationError(error)
        Mapper-->>Handler: localized message
    end

    Handler->>Handler: determineUIStyle()
    Note over Handler: Banner, Alert, or Inline

    Handler->>UI: show(message, style, actions)

    UI->>User: Display Error

    alt Retry Available
        UI->>UI: showRetryButton()
        User->>UI: Tap Retry
        UI->>Handler: retry()
    else Settings Action
        UI->>UI: showSettingsButton()
        User->>UI: Tap Settings
        UI->>UI: openAppSettings()
    end
```

---

## WF-ERR-004: Permission Denied Handling

Guide user to enable permissions.

```mermaid
sequenceDiagram
    participant App as Application
    participant Perm as PermissionManager
    participant UI as PermissionView
    participant User
    participant Settings as iOS Settings

    App->>Perm: checkMicrophonePermission()
    Perm-->>App: denied

    App->>UI: showPermissionRequired(type: .microphone)

    UI->>UI: buildExplanationView()
    Note over UI: Icon: microphone<br/>Title: "Microphone Access Required"<br/>Description: "LiveLingo needs..."

    UI->>User: Display Permission View

    UI->>UI: showOpenSettingsButton()
    User->>UI: Tap "Open Settings"

    UI->>Settings: UIApplication.openSettings()
    Settings->>User: Show App Settings

    User->>Settings: Toggle Microphone ON

    Settings->>App: applicationDidBecomeActive()
    App->>Perm: recheckPermissions()
    Perm-->>App: granted

    App->>UI: hidePermissionView()
    App->>App: proceedWithFeature()
```

---

## WF-ERR-005: Graceful Degradation

Fallback to alternatives when primary service fails.

```mermaid
sequenceDiagram
    participant VM as ViewModel
    participant Primary as PrimaryService
    participant Fallback as FallbackService
    participant UI as UserInterface
    participant User

    VM->>Primary: execute()

    alt Primary Success
        Primary-->>VM: result
        VM-->>UI: display result
    else Primary Failure
        Primary--xVM: error

        VM->>VM: checkFallbackAvailable()

        alt Fallback Available
            VM->>UI: showFallbackNotice()
            UI->>User: "Using alternative service"

            VM->>Fallback: execute()

            alt Fallback Success
                Fallback-->>VM: result
                VM->>VM: markQualityReduction()
                VM-->>UI: display result (with indicator)
            else Fallback Failure
                Fallback--xVM: error
                VM-->>UI: showFullError()
            end
        else No Fallback
            VM-->>UI: showError()
        end
    end
```

---

## Error Categorization

```mermaid
flowchart TD
    A[Error Occurred] --> B{Error Category}

    B -->|Network| C[Network Errors]
    C --> C1[Offline]
    C --> C2[Timeout]
    C --> C3[Server Error 5xx]
    C --> C4[Rate Limited 429]

    B -->|Permission| D[Permission Errors]
    D --> D1[Microphone Denied]
    D --> D2[Speech Recognition Denied]
    D --> D3[Location Denied]

    B -->|Authentication| E[Auth Errors]
    E --> E1[Token Expired]
    E --> E2[Invalid Credentials]
    E --> E3[Account Revoked]

    B -->|Resource| F[Resource Errors]
    F --> F1[Not Found 404]
    F --> F2[Model Not Downloaded]
    F --> F3[Storage Full]

    B -->|System| G[System Errors]
    G --> G1[Audio Session Error]
    G --> G2[Memory Pressure]
    G --> G3[Background Limitation]

    C1 --> H[Retry Strategy]
    C2 --> H
    C3 --> H

    D1 --> I[Permission Flow]
    D2 --> I

    E1 --> J[Re-authenticate]
    E2 --> J

    F2 --> K[Download Prompt]

    G1 --> L[Reinitialize]
    G2 --> M[Cleanup Memory]
```

---

## Error State Diagram

```mermaid
stateDiagram-v2
    [*] --> Normal

    Normal --> Error: error occurred
    Error --> Identifying: analyze error

    Identifying --> Retrying: retryable error
    Identifying --> ShowingError: non-retryable error
    Identifying --> Fallback: fallback available

    Retrying --> Normal: retry success
    Retrying --> ShowingError: max retries exceeded

    Fallback --> Normal: fallback success
    Fallback --> ShowingError: fallback failed

    ShowingError --> UserAction: display error UI
    UserAction --> Normal: retry / resolve
    UserAction --> [*]: dismiss
```

---

## Error Logging

```mermaid
sequenceDiagram
    participant Error as Error
    participant Logger as ErrorLogger
    participant Local as LocalLog
    participant Analytics as AnalyticsService
    participant Crash as CrashReporter

    Error->>Logger: log(error, context)

    Logger->>Logger: sanitizeError()
    Note over Logger: Remove sensitive data

    Logger->>Logger: enrichWithContext()
    Note over Logger: Add device info,<br/>app version, timestamp

    par Parallel Logging
        Logger->>Local: writeToFile(entry)
        Note over Local: Keep last 1000 entries
        and
        Logger->>Analytics: trackEvent("error", properties)
        Note over Analytics: If analytics enabled
    end

    alt Fatal Error
        Logger->>Crash: recordNonFatal(error)
    end

    alt Debug Build
        Logger->>Logger: printToConsole(detailed)
    end
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
