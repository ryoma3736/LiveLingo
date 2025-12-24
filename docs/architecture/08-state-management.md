# LiveLingo - State Management Architecture

## Application State Overview

```mermaid
stateDiagram-v2
    [*] --> NotRunning

    NotRunning --> Launching: app icon tapped
    Launching --> CheckingAuth: dependencies initialized

    CheckingAuth --> Onboarding: first launch
    CheckingAuth --> Authenticating: no valid session
    CheckingAuth --> Ready: valid session

    Onboarding --> PermissionRequest: onboarding complete
    PermissionRequest --> Ready: permissions granted

    Authenticating --> Ready: auth success
    Authenticating --> Authenticating: auth failed (retry)

    Ready --> Active: foreground
    Active --> Background: app backgrounded
    Background --> Active: app foregrounded
    Background --> Suspended: system suspends
    Suspended --> Active: app foregrounded
    Suspended --> NotRunning: system terminates

    Active --> [*]: user force quit
```

---

## Interpretation State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Configuring: startInterpretation()
    Configuring --> AudioReady: session configured
    AudioReady --> Listening: recognition started

    Listening --> Recognizing: speech detected
    Recognizing --> Listening: silence < threshold
    Recognizing --> Translating: pause detected

    Translating --> Speaking: translation complete
    Speaking --> Listening: playback complete

    Listening --> Paused: interruption.began
    Recognizing --> Paused: interruption.began
    Translating --> Paused: interruption.began
    Speaking --> Paused: interruption.began

    Paused --> Listening: interruption.ended (shouldResume)
    Paused --> Stopped: interruption.ended (noResume)

    Listening --> Stopping: stopInterpretation()
    Recognizing --> Stopping: stopInterpretation()
    Translating --> Stopping: stopInterpretation()
    Speaking --> Stopping: stopInterpretation()

    Stopping --> Saving: cleanup complete
    Saving --> Idle: saved

    state Configuring {
        [*] --> ConfiguringSession
        ConfiguringSession --> ActivatingSession
        ActivatingSession --> InitializingSTT
        InitializingSTT --> [*]
    }
```

---

## Authentication State Machine

```mermaid
stateDiagram-v2
    [*] --> Unknown

    Unknown --> Checking: app launch
    Checking --> SignedOut: no stored credentials
    Checking --> Validating: has stored credentials

    Validating --> SignedIn: credentials valid
    Validating --> Revoked: credentials revoked
    Validating --> SignedOut: credentials expired

    Revoked --> SignedOut: clear data

    SignedOut --> SigningIn: user initiates sign in
    SigningIn --> SignedIn: success
    SigningIn --> SignedOut: cancelled/failed

    SignedIn --> BiometricChallenge: access secure data
    BiometricChallenge --> SignedIn: success
    BiometricChallenge --> BiometricLocked: failed (retry available)
    BiometricLocked --> BiometricChallenge: retry
    BiometricLocked --> SignedIn: exceeded retries

    SignedIn --> SigningOut: user signs out
    SigningOut --> SignedOut: complete

    SignedIn --> SessionExpired: token expired
    SessionExpired --> SigningIn: refresh required
```

---

## Audio Session State Machine

```mermaid
stateDiagram-v2
    [*] --> Inactive

    Inactive --> Configuring: configureSession()
    Configuring --> Configured: success
    Configuring --> Error: failure

    Configured --> Activating: activateSession()
    Activating --> Active: success
    Activating --> Error: failure

    Active --> Interrupted: interruption.began
    Interrupted --> Active: interruption.ended (shouldResume)
    Interrupted --> Inactive: interruption.ended (noResume)

    Active --> RouteChanging: routeChange notification
    RouteChanging --> Active: route updated

    Active --> Resetting: mediaServicesReset
    Resetting --> Configuring: reinitialize

    Active --> Deactivating: deactivateSession()
    Deactivating --> Inactive: success

    Error --> Inactive: error handled

    state Interrupted {
        [*] --> PhoneCall
        [*] --> Siri
        [*] --> Alarm
        [*] --> OtherApp
    }
```

---

## Speech Recognition State Machine

```mermaid
stateDiagram-v2
    [*] --> Uninitialized

    Uninitialized --> CheckingPermission: initialize()
    CheckingPermission --> PermissionDenied: denied
    CheckingPermission --> Initializing: authorized

    PermissionDenied --> [*]

    Initializing --> Ready: SFSpeech available
    Initializing --> InitializingFallback: SFSpeech unavailable
    InitializingFallback --> Ready: WhisperKit loaded

    Ready --> StartingRecognition: startRecognition()
    StartingRecognition --> Listening: audio tap installed

    Listening --> Recognizing: voice detected
    Recognizing --> ProcessingPartial: partial result
    ProcessingPartial --> Recognizing: continue

    Recognizing --> ProcessingFinal: pause detected
    ProcessingFinal --> Listening: result emitted

    Listening --> Pausing: pauseRecognition()
    Recognizing --> Pausing: pauseRecognition()
    Pausing --> Paused: audio tap removed

    Paused --> Resuming: resumeRecognition()
    Resuming --> Listening: audio tap reinstalled

    Listening --> Stopping: stopRecognition()
    Recognizing --> Stopping: stopRecognition()
    Stopping --> Ready: cleanup complete
```

---

## Translation State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> CheckingCache: translate()
    CheckingCache --> Returning: cache hit
    CheckingCache --> CheckingNetwork: cache miss

    Returning --> Idle: complete

    CheckingNetwork --> SelectingProvider: online
    CheckingNetwork --> UsingOffline: offline

    SelectingProvider --> UsingApple: on-device preferred
    SelectingProvider --> UsingCloud: cloud preferred

    UsingOffline --> Translating: Apple available
    UsingOffline --> Error: no offline support

    UsingApple --> Translating: start
    UsingCloud --> SelectingCloudProvider: start

    SelectingCloudProvider --> UsingOpenAI: OpenAI selected
    SelectingCloudProvider --> UsingAnthropic: Anthropic selected

    UsingOpenAI --> Translating: API call
    UsingAnthropic --> Translating: API call

    Translating --> Caching: success
    Translating --> Retrying: transient error
    Translating --> Error: permanent error

    Retrying --> Translating: retry
    Retrying --> Error: max retries

    Caching --> Returning: cached

    Error --> Idle: error handled
```

---

## TTS State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Preparing: speak(text)
    Preparing --> SelectingVoice: validate input
    SelectingVoice --> SelectingProvider: voice selected

    SelectingProvider --> UsingAVS: system voice
    SelectingProvider --> UsingCoeFont: AI voice
    SelectingProvider --> UsingPersonal: personal voice

    UsingAVS --> Synthesizing: create utterance
    UsingCoeFont --> Synthesizing: API call
    UsingPersonal --> Synthesizing: create utterance

    Synthesizing --> Buffering: audio ready
    Buffering --> Playing: buffer filled (>=2)

    Playing --> Playing: next segment
    Playing --> Idle: all complete

    Playing --> Paused: pause()
    Paused --> Playing: resume()
    Paused --> Idle: stop()

    Playing --> Idle: stop()
    Synthesizing --> Idle: error
```

---

## Language State Machine

```mermaid
stateDiagram-v2
    [*] --> Loading

    Loading --> DefaultPair: no saved preference
    Loading --> RestoredPair: preference loaded

    DefaultPair --> Active: ja-JP to en-US
    RestoredPair --> Active: restored pair

    Active --> Selecting: open language menu
    Selecting --> Active: confirmed
    Selecting --> Active: cancelled

    Active --> Swapping: tap swap button
    Swapping --> Updating: swap source/target
    Updating --> Active: components updated

    Active --> Downloading: offline pack needed
    Downloading --> DownloadProgress: download started
    DownloadProgress --> Active: download complete
    DownloadProgress --> Active: download failed (fallback)

    Active --> Detecting: auto-detect enabled
    Detecting --> DetectionResult: analysis complete
    DetectionResult --> Active: high confidence
    DetectionResult --> Selecting: low confidence
```

---

## Navigation State Diagram

```mermaid
stateDiagram-v2
    [*] --> Splash

    Splash --> Onboarding: first launch
    Splash --> Home: returning user

    Onboarding --> Home: complete

    Home --> Interpretation: start button
    Home --> Settings: settings icon
    Home --> History: history icon
    Home --> Dictionary: dictionary icon

    Interpretation --> Summary: stop + view summary
    Interpretation --> Home: stop + done
    Summary --> Home: done

    Settings --> VoiceSettings: voice
    Settings --> LanguageSettings: language
    Settings --> PrivacySettings: privacy
    Settings --> Home: back

    VoiceSettings --> Settings: back
    LanguageSettings --> Settings: back
    PrivacySettings --> Settings: back

    History --> ConversationDetail: select
    History --> Home: back
    ConversationDetail --> History: back

    Dictionary --> GlossaryDetail: select
    Dictionary --> EntryEditor: add/edit
    Dictionary --> Home: back
    GlossaryDetail --> Dictionary: back
    EntryEditor --> GlossaryDetail: save/cancel
```

---

## Network State Machine

```mermaid
stateDiagram-v2
    [*] --> Unknown

    Unknown --> Checking: startMonitoring()
    Checking --> Online: path.satisfied
    Checking --> Offline: path.unsatisfied

    Online --> Offline: connection lost
    Offline --> Online: connection restored

    Online --> OnlineConstrained: expensive/constrained path
    OnlineConstrained --> Online: constraint removed
    OnlineConstrained --> Offline: connection lost

    state Online {
        [*] --> WiFi
        WiFi --> Cellular: route change
        Cellular --> WiFi: route change
    }

    state Offline {
        [*] --> WaitingReconnect
        WaitingReconnect --> Reconnecting: network detected
        Reconnecting --> WaitingReconnect: connection failed
    }
```

---

## Memory State Machine

```mermaid
stateDiagram-v2
    [*] --> Optimal

    Optimal --> Warning: usage > 75%
    Warning --> Optimal: usage normalized
    Warning --> Critical: usage > 92%

    Critical --> EmergencyCleanup: trigger cleanup
    EmergencyCleanup --> EvictingCaches: start
    EvictingCaches --> ReleasingBuffers: caches cleared
    ReleasingBuffers --> TruncatingHistory: buffers released
    TruncatingHistory --> Critical: cleanup complete

    Critical --> Warning: usage < 92%
    Warning --> Optimal: usage < 75%

    state EmergencyCleanup {
        [*] --> ClearTranslationCache
        ClearTranslationCache --> ClearAudioBuffers
        ClearAudioBuffers --> TruncateConversations
        TruncateConversations --> ForceGC
        ForceGC --> [*]
    }
```

---

## Combined State Overview

```mermaid
flowchart TB
    subgraph AppStates[Application States]
        AS[App State<br/>Active/Background/Suspended]
    end

    subgraph AuthStates[Auth States]
        Auth[Auth State<br/>SignedIn/SignedOut]
    end

    subgraph FeatureStates[Feature States]
        Interp[Interpretation State<br/>Idle/Active/Paused]
        Audio[Audio State<br/>Active/Interrupted]
        Lang[Language State<br/>Selected/Detecting]
        Net[Network State<br/>Online/Offline]
    end

    subgraph UIStates[UI States]
        Nav[Navigation State<br/>Current Screen]
        Modal[Modal State<br/>Alerts/Sheets]
    end

    AS --> AuthStates
    AS --> FeatureStates
    Auth --> FeatureStates
    FeatureStates --> UIStates
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
