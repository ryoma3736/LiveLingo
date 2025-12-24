# LiveLingo - Audio Session Management Workflows

## WF-AUD-001: Configure Audio Session

PlayAndRecord session setup for simultaneous input/output.

```mermaid
sequenceDiagram
    participant App as Application
    participant ASM as AudioSessionManager
    participant Session as AVAudioSession
    participant Config as AudioSessionConfiguration

    App->>ASM: configureSession()

    ASM->>Config: getConfiguration()
    Config-->>ASM: {category: playAndRecord,<br/>mode: voiceChat,<br/>options: [...]}

    ASM->>Session: setCategory(playAndRecord,<br/>mode: voiceChat,<br/>options: [defaultToSpeaker,<br/>allowBluetooth,<br/>allowBluetoothA2DP,<br/>mixWithOthers])

    alt Success
        Session-->>ASM: configured
        ASM->>Session: setPreferredSampleRate(16000)
        ASM->>Session: setPreferredIOBufferDuration(0.005)
        ASM-->>App: configuration complete
    else Error
        Session-->>ASM: error
        ASM->>ASM: handleConfigurationError()
        ASM-->>App: configurationFailed
    end
```

---

## WF-AUD-002: Handle Phone Call Interruption

Pause and resume interpretation during phone calls.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant NC as NotificationCenter
    participant ASM as AudioSessionManager
    participant STT as SpeechRecognitionManager
    participant TTS as TTSManager
    participant UI as InterpretationView

    System->>NC: post(interruptionNotification,<br/>type: began)
    NC->>ASM: handleInterruption(began)

    ASM->>ASM: isInterrupted = true
    ASM->>ASM: state = .interrupted(phoneCall)

    ASM->>STT: pauseRecognition()
    STT->>STT: suspendAudioTap()

    ASM->>TTS: pauseSpeaking()
    TTS->>TTS: player.pause()

    ASM->>UI: notify(interruptionBegan)
    UI->>UI: showInterruptionBanner("Phone Call")

    Note over System: Phone call in progress...

    System->>NC: post(interruptionNotification,<br/>type: ended,<br/>shouldResume: true)
    NC->>ASM: handleInterruption(ended)

    ASM->>ASM: isInterrupted = false
    ASM->>Session: setActive(true)

    ASM->>STT: resumeRecognition()
    STT->>STT: reinstallAudioTap()

    ASM->>TTS: resumeSpeaking()

    ASM->>UI: notify(interruptionEnded)
    UI->>UI: hideInterruptionBanner()
```

---

## WF-AUD-003: Handle Siri Interruption

Pause for Siri and resume after.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant ASM as AudioSessionManager
    participant Recog as SpeechRecognizer
    participant UI as InterpretationView

    System->>ASM: interruptionNotification<br/>(reason: builtInMicMuted)

    ASM->>ASM: determinInterruptionReason()
    Note over ASM: Siri detected

    ASM->>ASM: state = .interrupted(siri)
    ASM->>Recog: suspend()

    ASM->>UI: showInterruptionIndicator("Siri")

    Note over System: User interacting with Siri...

    System->>ASM: interruptionEnded

    ASM->>ASM: checkShouldResume()

    alt Should Resume
        ASM->>Recog: resume()
        ASM->>UI: hideInterruptionIndicator()
    else Manual Resume Required
        ASM->>UI: showResumeButton()
    end
```

---

## WF-AUD-004: Handle Route Change

Bluetooth connect/disconnect handling.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant ASM as AudioSessionManager
    participant Route as AudioRoute
    participant UI as DeviceIndicator

    System->>ASM: routeChangeNotification

    ASM->>ASM: parseRouteChangeReason()

    alt New Device Available (Bluetooth connected)
        ASM->>Route: getCurrentRoute()
        Route-->>ASM: {inputs: [bluetooth],<br/>outputs: [bluetooth]}

        ASM->>ASM: updateCurrentRoute()
        ASM->>UI: notify(deviceChanged: "AirPods")
        UI->>UI: showDeviceIcon("airpodspro")
        Note over UI: Audio now via Bluetooth
    else Old Device Unavailable (Bluetooth disconnected)
        ASM->>ASM: handleDeviceDisconnection()

        alt Was Using Headphones
            ASM->>ASM: route outputs to speaker
            ASM->>UI: notify(switchedToSpeaker)
            UI->>UI: showDeviceIcon("speaker.wave.3")
        end
    else Category Change
        ASM->>ASM: logCategoryChange()
    else Override
        ASM->>ASM: handleOverride()
    end
```

---

## WF-AUD-005: Handle Media Server Reset

System audio recovery after media server crash.

```mermaid
sequenceDiagram
    participant System as iOS System
    participant ASM as AudioSessionManager
    participant Engine as AVAudioEngine
    participant STT as SpeechRecognitionManager
    participant TTS as TTSManager

    System->>ASM: mediaServicesWereResetNotification

    Note over ASM: Media server crashed and reset

    ASM->>ASM: handleMediaServicesReset()

    ASM->>Engine: stop()
    ASM->>Engine: release()

    ASM->>ASM: reinitializeAudioSession()
    ASM->>ASM: configureSession()
    ASM->>ASM: activateSession()

    ASM->>Engine: AVAudioEngine()
    Engine->>Engine: prepare()

    ASM->>STT: reinitialize()
    STT->>STT: recreateRecognitionRequest()

    ASM->>TTS: reinitialize()
    TTS->>TTS: recreateSynthesizer()

    ASM-->>System: recovery complete
```

---

## WF-AUD-006: Device Selection

Input/output device manual selection.

```mermaid
sequenceDiagram
    participant User
    participant UI as AudioDeviceSelectionView
    participant ASM as AudioSessionManager
    participant Session as AVAudioSession

    User->>UI: Open Device Settings

    UI->>ASM: getAvailableInputs()
    ASM->>Session: availableInputs
    Session-->>ASM: [builtInMic, bluetoothHFP, headsetMic]
    ASM-->>UI: inputDevices

    UI->>ASM: getAvailableOutputs()
    ASM->>Session: currentRoute.outputs
    Session-->>ASM: [speaker, bluetoothA2DP]
    ASM-->>UI: outputDevices

    UI->>User: Display Device List

    User->>UI: Select Input (Bluetooth Mic)
    UI->>ASM: selectInputDevice(bluetoothHFP)
    ASM->>Session: setPreferredInput(bluetoothHFP)
    Session-->>ASM: success
    ASM-->>UI: input changed

    User->>UI: Select Output (Speaker)
    UI->>ASM: setOutputDevice(.speaker)
    ASM->>Session: overrideOutputAudioPort(.speaker)
    Session-->>ASM: success
    ASM-->>UI: output changed
```

---

## Audio Session State Diagram

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
    Interrupted --> Active: interruption.ended<br/>(shouldResume)
    Interrupted --> Inactive: interruption.ended<br/>(noResume)

    Active --> RouteChanging: routeChange
    RouteChanging --> Active: handled

    Active --> Resetting: mediaServicesReset
    Resetting --> Configuring: reinitialize

    Active --> Deactivating: deactivateSession()
    Deactivating --> Inactive: success

    Error --> Inactive: handled
```

---

## Audio Route Decision Tree

```mermaid
flowchart TD
    A[Check Audio Route] --> B{Bluetooth<br/>Connected?}

    B -->|Yes| C{User Preference?}
    C -->|Use Bluetooth| D[Route to Bluetooth]
    C -->|Use Speaker| E[Override to Speaker]

    B -->|No| F{Headphones<br/>Connected?}
    F -->|Yes| G[Route to Headphones]
    F -->|No| H[Route to Speaker]

    D --> I[Monitor Route Changes]
    E --> I
    G --> I
    H --> I

    I --> J{Route Changed?}
    J -->|Device Disconnected| K[Handle Disconnection]
    J -->|New Device| L[Handle New Device]
    J -->|No Change| I

    K --> M{Was Playing?}
    M -->|Yes| N[Pause Audio]
    M -->|No| I

    L --> O{Auto-Switch<br/>Enabled?}
    O -->|Yes| P[Switch to New Device]
    O -->|No| I
```

---

## Background Audio Behavior

```mermaid
sequenceDiagram
    participant App as Application
    participant BG as BackgroundAudioManager
    participant Session as AVAudioSession
    participant Engine as AVAudioEngine

    Note over App: App enters background

    App->>BG: handleAppDidEnterBackground()
    BG->>BG: beginBackgroundTask()

    BG->>Session: checkBackgroundAudioCapability()

    alt UIBackgroundModes includes "audio"
        Session-->>BG: background audio enabled
        BG->>Engine: continue recording
        Note over Engine: Recording continues<br/>but no STT (iOS limitation)
    else No background audio
        Session-->>BG: background audio disabled
        BG->>Engine: stop()
    end

    Note over App: App returns to foreground

    App->>BG: handleAppWillEnterForeground()
    BG->>BG: endBackgroundTask()

    alt Has Buffered Audio
        BG->>BG: processBufferedAudio()
    end

    BG->>Engine: resume full functionality
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
