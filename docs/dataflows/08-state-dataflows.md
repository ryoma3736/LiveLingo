# LiveLingo - State Management Data Flows

## DF-STATE-001: Application Lifecycle State Flow

App state transitions throughout lifecycle.

```mermaid
flowchart TB
    subgraph Launch[App Launch]
        NOT_RUNNING[Not Running]
        LAUNCHING[Launching]
        INIT_DI[Initialize DI Container]
    end

    subgraph Auth[Authentication Check]
        CHECK_AUTH[Check Auth State]
        HAS_SESSION{Has Valid Session?}
        FIRST_LAUNCH{First Launch?}
    end

    subgraph Onboarding[Onboarding Flow]
        WELCOME[Welcome Screen]
        PERM_REQ[Permission Requests]
        SETUP[Initial Setup]
    end

    subgraph Active[Active States]
        READY[Ready State]
        FOREGROUND[Active Foreground]
        INTERPRETING[Interpreting]
    end

    subgraph Background[Background States]
        BG_AUDIO[Background Audio]
        SUSPENDED[Suspended]
        SAVE_STATE[Save State]
    end

    subgraph Terminate[Termination]
        CLEANUP[Cleanup Resources]
        PERSIST[Persist Data]
        TERMINATED[Terminated]
    end

    NOT_RUNNING -->|app launch| LAUNCHING
    LAUNCHING --> INIT_DI
    INIT_DI --> CHECK_AUTH

    CHECK_AUTH --> HAS_SESSION
    HAS_SESSION -->|No| FIRST_LAUNCH
    HAS_SESSION -->|Yes| READY

    FIRST_LAUNCH -->|Yes| WELCOME
    FIRST_LAUNCH -->|No| CHECK_AUTH

    WELCOME --> PERM_REQ
    PERM_REQ --> SETUP
    SETUP --> READY

    READY --> FOREGROUND
    FOREGROUND --> INTERPRETING

    FOREGROUND -->|backgrounded| SAVE_STATE
    INTERPRETING -->|backgrounded| BG_AUDIO
    SAVE_STATE --> SUSPENDED
    BG_AUDIO --> SUSPENDED

    SUSPENDED -->|foregrounded| FOREGROUND
    SUSPENDED -->|terminated| CLEANUP
    CLEANUP --> PERSIST
    PERSIST --> TERMINATED
```

---

## DF-STATE-002: Interpretation State Flow

Real-time interpretation state machine.

```mermaid
flowchart TB
    subgraph Idle[Idle State]
        IDLE[Idle]
        READY_START[Ready to Start]
    end

    subgraph Starting[Starting Phase]
        CONFIG[Configuring]
        CONFIG_SESSION[Configure Audio Session]
        ACTIVATE[Activating Session]
        INIT_STT[Initialize STT]
    end

    subgraph Active[Active Interpretation]
        LISTENING[Listening]
        RECOGNIZING[Recognizing Speech]
        TRANSLATING[Translating]
        SPEAKING[Speaking Translation]
    end

    subgraph Paused[Paused States]
        PAUSED[Paused]
        INTERRUPTED[Interrupted<br/>Phone/Siri/Alarm]
    end

    subgraph Stopping[Stopping Phase]
        STOPPING[Stopping]
        CLEANUP[Cleanup]
        SAVING[Saving Conversation]
    end

    IDLE -->|startInterpretation()| CONFIG
    CONFIG --> CONFIG_SESSION
    CONFIG_SESSION --> ACTIVATE
    ACTIVATE --> INIT_STT
    INIT_STT --> LISTENING

    LISTENING -->|speech detected| RECOGNIZING
    RECOGNIZING -->|silence < 500ms| LISTENING
    RECOGNIZING -->|pause detected| TRANSLATING
    TRANSLATING --> SPEAKING
    SPEAKING -->|playback complete| LISTENING

    LISTENING -->|interruption| INTERRUPTED
    RECOGNIZING -->|interruption| INTERRUPTED
    TRANSLATING -->|interruption| INTERRUPTED
    SPEAKING -->|interruption| INTERRUPTED

    INTERRUPTED -->|shouldResume| LISTENING
    INTERRUPTED -->|noResume| STOPPING

    LISTENING -->|pauseInterpretation()| PAUSED
    PAUSED -->|resumeInterpretation()| LISTENING
    PAUSED -->|stopInterpretation()| STOPPING

    LISTENING -->|stopInterpretation()| STOPPING
    RECOGNIZING -->|stopInterpretation()| STOPPING
    TRANSLATING -->|stopInterpretation()| STOPPING
    SPEAKING -->|stopInterpretation()| STOPPING

    STOPPING --> CLEANUP
    CLEANUP --> SAVING
    SAVING --> IDLE
```

---

## DF-STATE-003: Audio Session State Flow

AVAudioSession state management.

```mermaid
flowchart TB
    subgraph Inactive[Inactive States]
        INACTIVE[Inactive]
        DEACTIVATED[Deactivated]
    end

    subgraph Configuration[Configuration Phase]
        CONFIGURING[Configuring]
        SET_CATEGORY[Set Category<br/>playAndRecord]
        SET_MODE[Set Mode<br/>voiceChat]
        SET_OPTIONS[Set Options]
        CONFIGURED[Configured]
    end

    subgraph Activation[Activation Phase]
        ACTIVATING[Activating]
        ACTIVE[Active]
    end

    subgraph Interruption[Interruption Handling]
        INTERRUPTED[Interrupted]
        PHONE_CALL[Phone Call]
        SIRI[Siri]
        ALARM[Alarm/Timer]
        OTHER_APP[Other App]
    end

    subgraph RouteChange[Route Changes]
        ROUTE_CHANGING[Route Changing]
        NEW_ROUTE[New Route Active]
    end

    subgraph Reset[Media Reset]
        RESETTING[Resetting]
        REINIT[Reinitialize]
    end

    subgraph Error[Error State]
        ERROR[Error]
        HANDLE_ERR[Handle Error]
    end

    INACTIVE -->|configure()| CONFIGURING
    CONFIGURING --> SET_CATEGORY
    SET_CATEGORY --> SET_MODE
    SET_MODE --> SET_OPTIONS
    SET_OPTIONS --> CONFIGURED
    CONFIGURING -->|error| ERROR

    CONFIGURED -->|activate()| ACTIVATING
    ACTIVATING --> ACTIVE
    ACTIVATING -->|error| ERROR

    ACTIVE -->|interruption.began| INTERRUPTED
    INTERRUPTED --> PHONE_CALL
    INTERRUPTED --> SIRI
    INTERRUPTED --> ALARM
    INTERRUPTED --> OTHER_APP

    INTERRUPTED -->|ended + shouldResume| ACTIVE
    INTERRUPTED -->|ended + noResume| INACTIVE

    ACTIVE -->|routeChange| ROUTE_CHANGING
    ROUTE_CHANGING --> NEW_ROUTE
    NEW_ROUTE --> ACTIVE

    ACTIVE -->|mediaServicesReset| RESETTING
    RESETTING --> REINIT
    REINIT --> CONFIGURING

    ACTIVE -->|deactivate()| DEACTIVATED
    DEACTIVATED --> INACTIVE

    ERROR --> HANDLE_ERR
    HANDLE_ERR --> INACTIVE
```

---

## DF-STATE-004: Authentication State Flow

User authentication state transitions.

```mermaid
flowchart TB
    subgraph Unknown[Initial State]
        UNKNOWN[Unknown]
        CHECKING[Checking Credentials]
    end

    subgraph SignedOut[Signed Out States]
        SIGNED_OUT[Signed Out]
        SIGNING_IN[Signing In]
    end

    subgraph Validation[Credential Validation]
        VALIDATING[Validating]
        REVOKED[Credentials Revoked]
        EXPIRED[Session Expired]
    end

    subgraph SignedIn[Signed In States]
        SIGNED_IN[Signed In]
        BIO_CHALLENGE[Biometric Challenge]
        BIO_LOCKED[Biometric Locked]
    end

    subgraph SignOut[Sign Out]
        SIGNING_OUT[Signing Out]
        CLEAR_DATA[Clear Sensitive Data]
    end

    UNKNOWN -->|app launch| CHECKING
    CHECKING -->|no credentials| SIGNED_OUT
    CHECKING -->|has credentials| VALIDATING

    VALIDATING -->|valid| SIGNED_IN
    VALIDATING -->|revoked| REVOKED
    VALIDATING -->|expired| EXPIRED

    REVOKED -->|clear data| SIGNED_OUT
    EXPIRED -->|re-auth| SIGNING_IN

    SIGNED_OUT -->|initiate sign in| SIGNING_IN
    SIGNING_IN -->|success| SIGNED_IN
    SIGNING_IN -->|failed/cancelled| SIGNED_OUT

    SIGNED_IN -->|access secure data| BIO_CHALLENGE
    BIO_CHALLENGE -->|success| SIGNED_IN
    BIO_CHALLENGE -->|failed + retry| BIO_LOCKED
    BIO_LOCKED -->|retry| BIO_CHALLENGE
    BIO_LOCKED -->|max retries| SIGNED_IN

    SIGNED_IN -->|sign out| SIGNING_OUT
    SIGNING_OUT --> CLEAR_DATA
    CLEAR_DATA --> SIGNED_OUT

    SIGNED_IN -->|token expired| EXPIRED
```

---

## DF-STATE-005: Network State Flow

Network connectivity state tracking.

```mermaid
flowchart TB
    subgraph Initial[Initial State]
        UNKNOWN[Unknown]
        START_MONITOR[Start NWPathMonitor]
    end

    subgraph Checking[Checking State]
        CHECKING[Checking]
        PATH_UPDATE[Path Update]
    end

    subgraph Online[Online States]
        ONLINE[Online]
        WIFI[WiFi Connected]
        CELLULAR[Cellular Only]
        CONSTRAINED[Constrained<br/>Low Data Mode]
    end

    subgraph Offline[Offline States]
        OFFLINE[Offline]
        WAITING[Waiting Reconnect]
        RECONNECTING[Reconnecting]
    end

    subgraph AppReaction[App Reactions]
        CLOUD_ENABLED[Cloud Features Enabled]
        OFFLINE_MODE[Offline Mode]
        REDUCED_QUALITY[Reduced Quality]
    end

    UNKNOWN -->|startMonitoring()| START_MONITOR
    START_MONITOR --> CHECKING

    CHECKING -->|path.satisfied| ONLINE
    CHECKING -->|path.unsatisfied| OFFLINE

    ONLINE --> WIFI
    ONLINE --> CELLULAR
    WIFI --> CONSTRAINED
    CELLULAR --> CONSTRAINED

    WIFI -->|connection lost| OFFLINE
    CELLULAR -->|connection lost| OFFLINE
    CONSTRAINED -->|connection lost| OFFLINE

    OFFLINE --> WAITING
    WAITING -->|network detected| RECONNECTING
    RECONNECTING -->|success| ONLINE
    RECONNECTING -->|failed| WAITING

    ONLINE --> CLOUD_ENABLED
    CONSTRAINED --> REDUCED_QUALITY
    OFFLINE --> OFFLINE_MODE
```

---

## DF-STATE-006: Language Selection State Flow

Source and target language management.

```mermaid
flowchart TB
    subgraph Loading[Loading State]
        LOADING[Loading]
        LOAD_PREFS[Load Preferences]
        DEFAULT{Has Saved?}
    end

    subgraph Initialize[Initialization]
        DEFAULT_PAIR[Default Pair<br/>ja-JP → en-US]
        RESTORED[Restored Pair]
    end

    subgraph Active[Active State]
        ACTIVE[Active]
        CURRENT[Current Selection]
    end

    subgraph Selection[Selection Mode]
        SELECTING[Selecting]
        SOURCE_SELECT[Source Language Menu]
        TARGET_SELECT[Target Language Menu]
        CONFIRM[Confirm Selection]
        CANCEL[Cancel]
    end

    subgraph Swap[Language Swap]
        SWAPPING[Swapping]
        UPDATE_STT[Update STT Language]
        UPDATE_TRANS[Update Translation]
        UPDATE_TTS[Update TTS Voice]
    end

    subgraph Download[Offline Pack]
        DOWNLOADING[Downloading]
        PROGRESS[Download Progress]
        COMPLETE[Download Complete]
        FAILED[Download Failed]
    end

    subgraph AutoDetect[Auto Detection]
        DETECTING[Detecting]
        ANALYZE[Analyze Speech]
        HIGH_CONF{Confidence >= 0.8?}
        DETECTED[Detected Language]
    end

    LOADING --> LOAD_PREFS
    LOAD_PREFS --> DEFAULT
    DEFAULT -->|No| DEFAULT_PAIR
    DEFAULT -->|Yes| RESTORED

    DEFAULT_PAIR --> ACTIVE
    RESTORED --> ACTIVE

    ACTIVE --> CURRENT
    ACTIVE -->|open menu| SELECTING
    SELECTING --> SOURCE_SELECT
    SELECTING --> TARGET_SELECT
    SOURCE_SELECT --> CONFIRM
    TARGET_SELECT --> CONFIRM
    SELECTING --> CANCEL
    CONFIRM --> ACTIVE
    CANCEL --> ACTIVE

    ACTIVE -->|tap swap| SWAPPING
    SWAPPING --> UPDATE_STT
    UPDATE_STT --> UPDATE_TRANS
    UPDATE_TRANS --> UPDATE_TTS
    UPDATE_TTS --> ACTIVE

    ACTIVE -->|offline needed| DOWNLOADING
    DOWNLOADING --> PROGRESS
    PROGRESS --> COMPLETE
    PROGRESS --> FAILED
    COMPLETE --> ACTIVE
    FAILED --> ACTIVE

    ACTIVE -->|auto-detect on| DETECTING
    DETECTING --> ANALYZE
    ANALYZE --> HIGH_CONF
    HIGH_CONF -->|Yes| DETECTED
    HIGH_CONF -->|No| SELECTING
    DETECTED --> ACTIVE
```

---

## DF-STATE-007: Memory Management State Flow

Memory pressure handling.

```mermaid
flowchart TB
    subgraph Monitoring[Memory Monitoring]
        MONITOR[Memory Monitor]
        CHECK_USAGE[Check Usage]
        USAGE[Current Usage %]
    end

    subgraph States[Memory States]
        OPTIMAL[Optimal<br/>< 75%]
        WARNING[Warning<br/>75-92%]
        CRITICAL[Critical<br/>> 92%]
    end

    subgraph WarningActions[Warning Actions]
        REDUCE_CACHE[Reduce Cache Size]
        TRIM_HISTORY[Trim History Buffer]
    end

    subgraph CriticalActions[Critical Actions]
        EMERGENCY[Emergency Cleanup]
        CLEAR_TRANS[Clear Translation Cache]
        CLEAR_AUDIO[Clear Audio Buffers]
        TRUNCATE_CONV[Truncate Conversations]
        FORCE_GC[Force GC]
    end

    subgraph Recovery[Recovery]
        RECHECK[Recheck Usage]
        NORMALIZED{Normalized?}
    end

    subgraph Notification[System Notification]
        LOW_MEM[Low Memory Warning]
        RESPOND[Respond to Warning]
    end

    MONITOR --> CHECK_USAGE
    CHECK_USAGE --> USAGE

    USAGE -->|< 75%| OPTIMAL
    USAGE -->|75-92%| WARNING
    USAGE -->|> 92%| CRITICAL

    WARNING --> REDUCE_CACHE
    WARNING --> TRIM_HISTORY

    CRITICAL --> EMERGENCY
    EMERGENCY --> CLEAR_TRANS
    CLEAR_TRANS --> CLEAR_AUDIO
    CLEAR_AUDIO --> TRUNCATE_CONV
    TRUNCATE_CONV --> FORCE_GC

    FORCE_GC --> RECHECK
    REDUCE_CACHE --> RECHECK
    TRIM_HISTORY --> RECHECK

    RECHECK --> NORMALIZED
    NORMALIZED -->|No| EMERGENCY
    NORMALIZED -->|Yes| OPTIMAL

    LOW_MEM --> RESPOND
    RESPOND --> EMERGENCY
```

---

## DF-STATE-008: Navigation State Flow

Screen navigation and modal management.

```mermaid
flowchart TB
    subgraph Root[Root Navigation]
        SPLASH[Splash Screen]
        ONBOARDING[Onboarding]
        HOME[Home Screen]
    end

    subgraph MainNav[Main Navigation]
        INTERP[Interpretation]
        SETTINGS[Settings]
        HISTORY[History]
        DICTIONARY[Dictionary]
    end

    subgraph SubNav[Sub Navigation]
        VOICE_SETTINGS[Voice Settings]
        LANG_SETTINGS[Language Settings]
        PRIVACY_SETTINGS[Privacy Settings]
        CONV_DETAIL[Conversation Detail]
        GLOSSARY_DETAIL[Glossary Detail]
        ENTRY_EDITOR[Entry Editor]
    end

    subgraph Modals[Modal Presentations]
        SUMMARY[Interpretation Summary]
        SHARE[Share Sheet]
        ALERT[Alert Dialog]
    end

    subgraph Navigation[Navigation Actions]
        PUSH[Push View]
        POP[Pop View]
        PRESENT[Present Modal]
        DISMISS[Dismiss Modal]
    end

    SPLASH -->|first launch| ONBOARDING
    SPLASH -->|returning user| HOME
    ONBOARDING --> HOME

    HOME -->|start| INTERP
    HOME -->|settings icon| SETTINGS
    HOME -->|history icon| HISTORY
    HOME -->|dictionary icon| DICTIONARY

    INTERP -->|stop + summary| SUMMARY
    INTERP -->|stop + done| HOME
    SUMMARY -->|done| HOME

    SETTINGS --> VOICE_SETTINGS
    SETTINGS --> LANG_SETTINGS
    SETTINGS --> PRIVACY_SETTINGS
    VOICE_SETTINGS --> SETTINGS
    LANG_SETTINGS --> SETTINGS
    PRIVACY_SETTINGS --> SETTINGS
    SETTINGS --> HOME

    HISTORY --> CONV_DETAIL
    CONV_DETAIL --> HISTORY
    HISTORY --> HOME

    DICTIONARY --> GLOSSARY_DETAIL
    GLOSSARY_DETAIL --> DICTIONARY
    GLOSSARY_DETAIL --> ENTRY_EDITOR
    ENTRY_EDITOR --> GLOSSARY_DETAIL
    DICTIONARY --> HOME

    PUSH --> MainNav
    PUSH --> SubNav
    POP --> MainNav
    POP --> SubNav
    PRESENT --> Modals
    DISMISS --> Modals
```

---

## DF-STATE-009: Translation State Flow

Translation request state machine.

```mermaid
flowchart TB
    subgraph Initial[Initial State]
        IDLE[Idle]
        REQUEST[Translation Request]
    end

    subgraph CachePhase[Cache Phase]
        CHECK_CACHE[Checking Cache]
        CACHE_HIT{Cache Hit?}
        RETURN_CACHED[Return Cached]
    end

    subgraph NetworkPhase[Network Phase]
        CHECK_NET[Checking Network]
        ONLINE{Online?}
    end

    subgraph ProviderPhase[Provider Selection]
        SELECT[Selecting Provider]
        USE_APPLE[Using Apple]
        USE_CLOUD[Using Cloud]
    end

    subgraph Execution[Translation Execution]
        TRANSLATING[Translating]
        SUCCESS[Success]
        TRANSIENT_ERR[Transient Error]
        PERMANENT_ERR[Permanent Error]
    end

    subgraph Retry[Retry Logic]
        RETRYING[Retrying]
        MAX_RETRIES{Max Retries?}
    end

    subgraph Caching[Cache Storage]
        CACHING[Caching Result]
    end

    subgraph Complete[Completion]
        RETURNING[Returning Result]
        ERROR[Error State]
    end

    IDLE -->|translate()| REQUEST
    REQUEST --> CHECK_CACHE

    CHECK_CACHE --> CACHE_HIT
    CACHE_HIT -->|Yes| RETURN_CACHED
    CACHE_HIT -->|No| CHECK_NET

    CHECK_NET --> ONLINE
    ONLINE -->|No| USE_APPLE
    ONLINE -->|Yes| SELECT

    SELECT -->|prefer on-device| USE_APPLE
    SELECT -->|prefer cloud| USE_CLOUD

    USE_APPLE --> TRANSLATING
    USE_CLOUD --> TRANSLATING

    TRANSLATING --> SUCCESS
    TRANSLATING --> TRANSIENT_ERR
    TRANSLATING --> PERMANENT_ERR

    TRANSIENT_ERR --> RETRYING
    RETRYING --> MAX_RETRIES
    MAX_RETRIES -->|No| TRANSLATING
    MAX_RETRIES -->|Yes| ERROR

    PERMANENT_ERR --> ERROR

    SUCCESS --> CACHING
    CACHING --> RETURNING
    RETURN_CACHED --> RETURNING
    RETURNING --> IDLE
    ERROR --> IDLE
```

---

## DF-STATE-010: Combined State Overview Flow

Hierarchical state relationships.

```mermaid
flowchart TB
    subgraph AppLevel[Application Level]
        APP_STATE[App State<br/>Active/Background/Suspended]
    end

    subgraph AuthLevel[Auth Level]
        AUTH_STATE[Auth State<br/>SignedIn/SignedOut]
    end

    subgraph FeatureLevel[Feature Level]
        INTERP_STATE[Interpretation State<br/>Idle/Active/Paused]
        AUDIO_STATE[Audio State<br/>Active/Interrupted]
        LANG_STATE[Language State<br/>Selected/Detecting]
        NET_STATE[Network State<br/>Online/Offline]
    end

    subgraph UILevel[UI Level]
        NAV_STATE[Navigation State<br/>Current Screen]
        MODAL_STATE[Modal State<br/>Alerts/Sheets]
    end

    subgraph DataLevel[Data Level]
        SYNC_STATE[Sync State<br/>Synced/Pending/Conflict]
        CACHE_STATE[Cache State<br/>Fresh/Stale/Empty]
    end

    subgraph Dependencies[State Dependencies]
        DEP1[App Active → Features Available]
        DEP2[Auth SignedIn → Data Access]
        DEP3[Network Online → Cloud Features]
        DEP4[Audio Active → Interpretation Active]
    end

    APP_STATE --> AUTH_STATE
    APP_STATE --> FeatureLevel
    AUTH_STATE --> FeatureLevel
    AUTH_STATE --> DataLevel
    FeatureLevel --> UILevel
    NET_STATE --> SYNC_STATE
    NET_STATE --> CACHE_STATE

    APP_STATE -.-> DEP1
    AUTH_STATE -.-> DEP2
    NET_STATE -.-> DEP3
    AUDIO_STATE -.-> DEP4
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 10 state management data flows | AI Agent |
