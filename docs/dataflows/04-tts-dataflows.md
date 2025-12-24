# LiveLingo - Text-to-Speech (TTS) Data Flows

## DF-TTS-001: TTS Provider Selection Flow

Voice synthesis provider routing.

```mermaid
flowchart TB
    subgraph Input[TTS Request]
        TEXT[Translated Text]
        LANG[Target Language]
        PREF[Voice Preference]
    end

    subgraph UserPreference[User Preference Check]
        CHECK_PREF[Check Voice Setting]
        VOICE_TYPE{Voice Type}
    end

    subgraph SystemVoice[System Voice Path]
        AVS[AVSpeechSynthesizer]
        SELECT_VOICE[Select Voice for Language]
        CONFIGURE[Configure Rate/Pitch]
    end

    subgraph AIVoice[AI Voice Path]
        CHECK_NET{Network Available?}
        COEFONT[CoeFont API]
        FALLBACK_SYS[Fallback to System]
    end

    subgraph PersonalVoice[Personal Voice Path]
        CHECK_PV{Personal Voice<br/>Available?}
        CHECK_AUTH{Authorized?}
        USE_PV[Use Personal Voice]
        PROMPT_CREATE[Prompt to Create]
    end

    subgraph Output[TTS Output]
        SYNTHESIZE[Synthesize Audio]
        PLAY[Play Audio]
    end

    TEXT --> CHECK_PREF
    LANG --> CHECK_PREF
    PREF --> CHECK_PREF

    CHECK_PREF --> VOICE_TYPE

    VOICE_TYPE -->|System| AVS
    VOICE_TYPE -->|AI| CHECK_NET
    VOICE_TYPE -->|Personal| CHECK_PV

    AVS --> SELECT_VOICE
    SELECT_VOICE --> CONFIGURE
    CONFIGURE --> SYNTHESIZE

    CHECK_NET -->|Yes| COEFONT
    CHECK_NET -->|No| FALLBACK_SYS
    COEFONT --> SYNTHESIZE
    FALLBACK_SYS --> AVS

    CHECK_PV -->|Yes| CHECK_AUTH
    CHECK_PV -->|No| PROMPT_CREATE
    CHECK_AUTH -->|Yes| USE_PV
    CHECK_AUTH -->|No| AVS
    USE_PV --> SYNTHESIZE

    SYNTHESIZE --> PLAY
```

---

## DF-TTS-002: AVSpeechSynthesizer Flow

System TTS using Apple's built-in synthesizer.

```mermaid
flowchart TB
    subgraph Input[Synthesis Request]
        TEXT[Text to Speak]
        LANG[Language Code]
        SETTINGS[Voice Settings<br/>rate, pitch, volume]
    end

    subgraph VoiceSelection[Voice Selection]
        GET_VOICES[Get Available Voices]
        FILTER_LANG[Filter by Language]
        QUALITY[Select Quality<br/>Enhanced > Default]
        SELECTED[Selected Voice]
    end

    subgraph UtteranceCreation[Utterance Creation]
        CREATE_UTT[Create AVSpeechUtterance]
        SET_VOICE[Set Voice]
        SET_RATE[Set Rate: 0.4-0.6]
        SET_PITCH[Set Pitch: 0.8-1.2]
        SET_VOL[Set Volume: 0.0-1.0]
    end

    subgraph Synthesis[Synthesis Process]
        SYNTH[AVSpeechSynthesizer]
        SPEAK[speak(utterance)]
        DELEGATE[Delegate Callbacks]
    end

    subgraph Events[Speech Events]
        DID_START[didStart]
        DID_CONTINUE[didContinue]
        DID_PAUSE[didPause]
        DID_CANCEL[didCancel]
        DID_FINISH[didFinish]
    end

    subgraph Output[Audio Output]
        AUDIO_OUT[Audio Session Output]
        SPEAKER[Speaker/Bluetooth]
    end

    TEXT --> CREATE_UTT
    LANG --> GET_VOICES
    GET_VOICES --> FILTER_LANG
    FILTER_LANG --> QUALITY
    QUALITY --> SELECTED

    SELECTED --> SET_VOICE
    CREATE_UTT --> SET_VOICE
    SETTINGS --> SET_RATE
    SETTINGS --> SET_PITCH
    SETTINGS --> SET_VOL

    SET_VOICE --> SET_RATE
    SET_RATE --> SET_PITCH
    SET_PITCH --> SET_VOL
    SET_VOL --> SPEAK

    SYNTH --> SPEAK
    SPEAK --> DELEGATE

    DELEGATE --> DID_START
    DELEGATE --> DID_CONTINUE
    DELEGATE --> DID_PAUSE
    DELEGATE --> DID_CANCEL
    DELEGATE --> DID_FINISH

    SPEAK --> AUDIO_OUT
    AUDIO_OUT --> SPEAKER
```

---

## DF-TTS-003: CoeFont API Synthesis Flow

AI voice synthesis via CoeFont cloud service.

```mermaid
flowchart TB
    subgraph Input[Synthesis Request]
        TEXT[Text to Synthesize]
        COEFONT_ID[CoeFont Voice ID]
        SPEED[Speed: 0.5-2.0]
        PITCH[Pitch: -300-300]
    end

    subgraph Authentication[HMAC-SHA256 Auth]
        TIMESTAMP[Generate Timestamp<br/>Unix Epoch]
        BODY[Create Request Body<br/>JSON]
        CONCAT[Concatenate<br/>timestamp + body]
        HMAC[HMAC-SHA256<br/>with secret]
        HEX[Hex Encode Signature]
    end

    subgraph Request[API Request]
        HEADERS[Set Headers<br/>Authorization, X-Coefont-Date,<br/>X-Coefont-Content]
        SEND[POST /v2/text2speech]
    end

    subgraph Response[Response Handling]
        STATUS{Status Code}
        SUCCESS[200: Audio Data]
        RATE_LIMIT[429: Rate Limited]
        AUTH_FAIL[401: Auth Failed]
        SERVER_ERR[500: Server Error]
    end

    subgraph AudioProcessing[Audio Processing]
        DECODE[Decode MP3/WAV]
        BUFFER[Create Audio Buffer]
        QUEUE[Add to Play Queue]
    end

    subgraph Playback[Audio Playback]
        PLAYER[Audio Player]
        OUTPUT[Speaker Output]
    end

    TEXT --> BODY
    COEFONT_ID --> BODY
    SPEED --> BODY
    PITCH --> BODY

    TIMESTAMP --> CONCAT
    BODY --> CONCAT
    CONCAT --> HMAC
    HMAC --> HEX

    TIMESTAMP --> HEADERS
    HEX --> HEADERS
    HEADERS --> SEND
    BODY --> SEND

    SEND --> STATUS
    STATUS --> SUCCESS
    STATUS --> RATE_LIMIT
    STATUS --> AUTH_FAIL
    STATUS --> SERVER_ERR

    SUCCESS --> DECODE
    DECODE --> BUFFER
    BUFFER --> QUEUE

    QUEUE --> PLAYER
    PLAYER --> OUTPUT
```

---

## DF-TTS-004: Personal Voice (iOS 17+) Flow

User's cloned voice synthesis.

```mermaid
flowchart TB
    subgraph Availability[Availability Check]
        CHECK_IOS[Check iOS Version<br/>>= 17]
        CHECK_FEATURE[Check Feature Available]
    end

    subgraph Authorization[Authorization]
        AUTH_STATUS[Check Authorization Status]
        NOT_DET{Not Determined?}
        REQUEST_AUTH[Request Authorization]
        AUTH_RESULT[Authorization Result]
    end

    subgraph VoiceAccess[Voice Access]
        FETCH_VOICES[Fetch Personal Voices]
        VOICES_EXIST{Voices Exist?}
        SELECT_VOICE[Select Voice]
        PROMPT_CREATE[Prompt User<br/>to Create Voice]
    end

    subgraph Synthesis[Voice Synthesis]
        CREATE_UTT[Create Utterance]
        SET_PV[Set Personal Voice]
        SYNTHESIZE[Synthesize]
    end

    subgraph Fallback[Fallback Path]
        USE_SYSTEM[Use System Voice]
    end

    subgraph Output[Output]
        AUDIO[Audio Output]
        NOTIFY[Notify Using Personal Voice]
    end

    CHECK_IOS --> CHECK_FEATURE
    CHECK_FEATURE --> AUTH_STATUS

    AUTH_STATUS --> NOT_DET
    NOT_DET -->|Yes| REQUEST_AUTH
    NOT_DET -->|No| AUTH_RESULT

    REQUEST_AUTH --> AUTH_RESULT

    AUTH_RESULT -->|Authorized| FETCH_VOICES
    AUTH_RESULT -->|Denied| USE_SYSTEM

    FETCH_VOICES --> VOICES_EXIST
    VOICES_EXIST -->|Yes| SELECT_VOICE
    VOICES_EXIST -->|No| PROMPT_CREATE
    PROMPT_CREATE --> USE_SYSTEM

    SELECT_VOICE --> CREATE_UTT
    CREATE_UTT --> SET_PV
    SET_PV --> SYNTHESIZE

    SYNTHESIZE --> AUDIO
    SYNTHESIZE --> NOTIFY

    USE_SYSTEM --> AUDIO
```

---

## DF-TTS-005: Streaming Audio Queue Flow

Pre-buffered playback for seamless audio.

```mermaid
flowchart TB
    subgraph Input[Text Stream Input]
        SEG1[Segment 1]
        SEG2[Segment 2]
        SEG3[Segment 3]
        SEG4[Segment 4]
    end

    subgraph Synthesis[Parallel Synthesis]
        SYNTH1[Synthesize 1]
        SYNTH2[Synthesize 2]
        SYNTH3[Synthesize 3]
        SYNTH4[Synthesize 4]
    end

    subgraph AudioBuffer[Audio Buffer Pool]
        BUF1[Audio Buffer 1]
        BUF2[Audio Buffer 2]
        BUF3[Audio Buffer 3]
        BUF4[Audio Buffer 4]
    end

    subgraph Queue[Playback Queue]
        PREBUFFER[Pre-buffer Count: 2]
        QUEUE_STATE[Queue State]
        CHECK{Buffer >= 2?}
    end

    subgraph Playback[Sequential Playback]
        CURRENT[Currently Playing]
        NEXT[Next Up]
        WAITING[Waiting]
    end

    subgraph Events[Playback Events]
        FINISHED[Segment Finished]
        ADVANCE[Advance Queue]
        REQUEST_MORE[Request More Synthesis]
    end

    SEG1 --> SYNTH1 --> BUF1
    SEG2 --> SYNTH2 --> BUF2
    SEG3 --> SYNTH3 --> BUF3
    SEG4 --> SYNTH4 --> BUF4

    BUF1 --> QUEUE_STATE
    BUF2 --> QUEUE_STATE
    PREBUFFER --> CHECK
    QUEUE_STATE --> CHECK

    CHECK -->|Yes| CURRENT
    CHECK -->|No| WAITING

    BUF1 --> CURRENT
    BUF2 --> NEXT

    CURRENT --> FINISHED
    FINISHED --> ADVANCE
    ADVANCE --> CURRENT
    ADVANCE --> REQUEST_MORE
```

---

## DF-TTS-006: Voice Configuration Flow

Voice selection and settings management.

```mermaid
flowchart TB
    subgraph UI[Voice Settings UI]
        OPEN[Open Voice Settings]
        LANG_SELECT[Select Language]
    end

    subgraph LoadVoices[Load Available Voices]
        SYSTEM_VOICES[System Voices<br/>AVSpeechSynthesisVoice]
        AI_VOICES[AI Voices<br/>CoeFont Catalog]
        PERSONAL_VOICES[Personal Voices<br/>iOS 17+]
    end

    subgraph Grouping[Voice Grouping]
        GROUP_LANG[Group by Language]
        GROUP_TYPE[Group by Type]
        DISPLAY[Display List]
    end

    subgraph Selection[Voice Selection]
        SELECT[User Selects Voice]
        PREVIEW[Preview Voice<br/>Sample Text]
    end

    subgraph Settings[Voice Settings]
        RATE[Adjust Speech Rate]
        PITCH[Adjust Pitch]
        VOLUME[Adjust Volume]
    end

    subgraph Save[Save Preferences]
        VALIDATE[Validate Settings]
        STORE[Store to UserDefaults]
        NOTIFY[Notify Observers]
    end

    OPEN --> LANG_SELECT
    LANG_SELECT --> SYSTEM_VOICES
    LANG_SELECT --> AI_VOICES
    LANG_SELECT --> PERSONAL_VOICES

    SYSTEM_VOICES --> GROUP_LANG
    AI_VOICES --> GROUP_LANG
    PERSONAL_VOICES --> GROUP_LANG

    GROUP_LANG --> GROUP_TYPE
    GROUP_TYPE --> DISPLAY

    DISPLAY --> SELECT
    SELECT --> PREVIEW

    PREVIEW --> RATE
    RATE --> PITCH
    PITCH --> VOLUME

    VOLUME --> VALIDATE
    VALIDATE --> STORE
    STORE --> NOTIFY
```

---

## DF-TTS-007: Audio Session Configuration for TTS Flow

Audio session setup for playback.

```mermaid
flowchart TB
    subgraph Trigger[TTS Trigger]
        TTS_REQUEST[TTS Request]
    end

    subgraph SessionConfig[Session Configuration]
        SET_CATEGORY[Set Category<br/>playAndRecord]
        SET_MODE[Set Mode<br/>voiceChat]
        SET_OPTIONS[Set Options<br/>defaultToSpeaker,<br/>allowBluetooth,<br/>allowBluetoothA2DP]
    end

    subgraph Activation[Session Activation]
        ACTIVATE[Activate Session]
        CHECK_ACTIVE{Already Active?}
    end

    subgraph RouteCheck[Route Check]
        GET_ROUTE[Get Current Route]
        CHECK_BT{Bluetooth Connected?}
    end

    subgraph OutputConfig[Output Configuration]
        BT_OUTPUT[Bluetooth Output]
        SPEAKER_OUTPUT[Speaker Output]
        OVERRIDE[Override Output Port<br/>if needed]
    end

    subgraph Ready[Ready for TTS]
        TTS_READY[Start Synthesis]
        PLAY[Play Audio]
    end

    TTS_REQUEST --> SET_CATEGORY
    SET_CATEGORY --> SET_MODE
    SET_MODE --> SET_OPTIONS

    SET_OPTIONS --> CHECK_ACTIVE
    CHECK_ACTIVE -->|No| ACTIVATE
    CHECK_ACTIVE -->|Yes| GET_ROUTE

    ACTIVATE --> GET_ROUTE

    GET_ROUTE --> CHECK_BT
    CHECK_BT -->|Yes| BT_OUTPUT
    CHECK_BT -->|No| OVERRIDE
    OVERRIDE --> SPEAKER_OUTPUT

    BT_OUTPUT --> TTS_READY
    SPEAKER_OUTPUT --> TTS_READY

    TTS_READY --> PLAY
```

---

## DF-TTS-008: TTS Error Recovery Flow

Error handling and fallback strategies.

```mermaid
flowchart TB
    subgraph Errors[Error Sources]
        AVS_ERR[AVS Synthesis Error]
        CF_ERR[CoeFont API Error]
        PV_ERR[Personal Voice Error]
        AUDIO_ERR[Audio Session Error]
    end

    subgraph Assessment[Error Assessment]
        CLASSIFY[Classify Error]
        SOURCE{Error Source}
    end

    subgraph CoeFontRecovery[CoeFont Recovery]
        CF_RETRY{Retry?}
        CF_BACKOFF[Exponential Backoff]
        CF_FALLBACK[Fallback to System]
    end

    subgraph AVSRecovery[AVS Recovery]
        AVS_RESET[Reset Synthesizer]
        AVS_REINIT[Reinitialize]
        AVS_RETRY[Retry Utterance]
    end

    subgraph AudioRecovery[Audio Session Recovery]
        REACTIVATE[Reactivate Session]
        RESET_ROUTE[Reset Audio Route]
        RECONFIGURE[Reconfigure Session]
    end

    subgraph FinalFallback[Final Fallback]
        SKIP_AUDIO[Skip Audio Output]
        DISPLAY_ONLY[Display Text Only]
        NOTIFY_USER[Notify User]
    end

    subgraph Success[Success Path]
        RESUME[Resume Playback]
        CONTINUE[Continue Queue]
    end

    AVS_ERR --> CLASSIFY
    CF_ERR --> CLASSIFY
    PV_ERR --> CLASSIFY
    AUDIO_ERR --> CLASSIFY

    CLASSIFY --> SOURCE

    SOURCE -->|CoeFont| CF_RETRY
    CF_RETRY -->|Yes| CF_BACKOFF
    CF_RETRY -->|No| CF_FALLBACK
    CF_BACKOFF --> RESUME
    CF_FALLBACK --> AVS_RESET

    SOURCE -->|AVS| AVS_RESET
    AVS_RESET --> AVS_REINIT
    AVS_REINIT --> AVS_RETRY
    AVS_RETRY --> RESUME

    SOURCE -->|Audio| REACTIVATE
    REACTIVATE --> RESET_ROUTE
    RESET_ROUTE --> RECONFIGURE
    RECONFIGURE --> RESUME

    AVS_RETRY -->|Fail| SKIP_AUDIO
    CF_FALLBACK -->|Fail| SKIP_AUDIO

    SKIP_AUDIO --> DISPLAY_ONLY
    DISPLAY_ONLY --> NOTIFY_USER

    RESUME --> CONTINUE
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 8 TTS data flows | AI Agent |
