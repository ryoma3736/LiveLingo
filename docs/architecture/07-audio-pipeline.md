# LiveLingo - Audio Pipeline Architecture

## Complete Audio Pipeline

```mermaid
flowchart TB
    subgraph Input[Audio Input Stage]
        Mic[Microphone]
        BT_In[Bluetooth Input]
        Session[AVAudioSession<br/>PlayAndRecord]
    end

    subgraph Engine[Audio Engine Stage]
        AE[AVAudioEngine]
        InputNode[Input Node]
        Tap[Audio Tap<br/>512 frames @ 16kHz]
        Buffer[Audio Buffer Pool]
    end

    subgraph Processing[Processing Stage]
        VAD[Voice Activity Detection]
        Pause[Pause Detection<br/>500ms threshold]
        Dia[Speaker Diarization<br/>2 speakers max]
    end

    subgraph STT[Speech Recognition Stage]
        SF[SFSpeechRecognizer<br/>Primary]
        WK[WhisperKit<br/>Fallback]
        Partial[Partial Results]
        Final[Final Results]
    end

    subgraph Translation[Translation Stage]
        Trans[Translation Engine]
        Context[Context Manager]
        Cache[Translation Cache]
    end

    subgraph TTS[Speech Synthesis Stage]
        Queue[Audio Queue<br/>Pre-buffer 2]
        AVS[AVSpeechSynthesizer]
        CF[CoeFont API]
    end

    subgraph Output[Audio Output Stage]
        OutputNode[Output Node]
        Speaker[Speaker]
        BT_Out[Bluetooth Output]
    end

    Mic --> Session
    BT_In --> Session
    Session --> AE
    AE --> InputNode
    InputNode --> Tap
    Tap --> Buffer

    Buffer --> VAD
    VAD --> Pause
    Buffer --> Dia
    Buffer --> SF
    Buffer --> WK

    SF --> Partial
    WK --> Partial
    Pause --> Final
    SF --> Final
    WK --> Final
    Dia --> Final

    Final --> Trans
    Context --> Trans
    Trans --> Cache
    Cache --> Queue

    Queue --> AVS
    Queue --> CF
    AVS --> OutputNode
    CF --> OutputNode
    OutputNode --> Speaker
    OutputNode --> BT_Out
```

---

## Audio Engine Configuration

```mermaid
flowchart TB
    subgraph Config[AVAudioSession Configuration]
        Category[Category: PlayAndRecord]
        Mode[Mode: VoiceChat]
        Options[Options]
    end

    subgraph OptionsList[Session Options]
        O1[DefaultToSpeaker]
        O2[AllowBluetooth]
        O3[AllowBluetoothA2DP]
        O4[MixWithOthers]
    end

    subgraph AudioParams[Audio Parameters]
        SampleRate[Sample Rate: 16000 Hz]
        BufferDuration[Buffer Duration: 0.005s]
        IOBufferDuration[IO Buffer: 512 frames]
        Channels[Channels: Mono]
    end

    subgraph Engine[Engine Setup]
        AE[AVAudioEngine]
        InputNode[Input Node]
        OutputNode[Output Node]
        Format[Audio Format<br/>PCM Float32]
    end

    Category --> Config
    Mode --> Config
    Options --> Config

    O1 --> Options
    O2 --> Options
    O3 --> Options
    O4 --> Options

    SampleRate --> AudioParams
    BufferDuration --> AudioParams
    IOBufferDuration --> AudioParams
    Channels --> AudioParams

    Config --> AE
    AudioParams --> AE
    AE --> InputNode
    AE --> OutputNode
    Format --> InputNode
```

---

## Real-time Latency Budget

```mermaid
gantt
    title Audio Pipeline Latency Budget (Target: <1000ms)
    dateFormat X
    axisFormat %Lms

    section Audio Input
    Buffer Fill (32ms)    :0, 32

    section STT
    Recognition (200-400ms)    :32, 232

    section Translation
    API Call (300-500ms)    :232, 432

    section TTS
    Synthesis (100-200ms)    :432, 532
    Playback Start    :532, 550

    section Total
    End-to-End Target    :0, 1000
```

---

## Voice Activity Detection

```mermaid
flowchart TB
    subgraph Input[Audio Input]
        Buffer[Audio Buffer<br/>512 samples]
    end

    subgraph Analysis[Signal Analysis]
        RMS[Calculate RMS]
        Energy[Energy Level<br/>dB]
        Threshold[Threshold<br/>-40dB]
    end

    subgraph Decision[Voice Decision]
        Compare[Compare to Threshold]
        Hysteresis[Hysteresis<br/>Prevent Flutter]
        State[Voice State]
    end

    subgraph Output[VAD Output]
        Active[Voice Active]
        Inactive[Voice Inactive]
        Transition[State Transition]
    end

    Buffer --> RMS
    RMS --> Energy
    Energy --> Compare
    Threshold --> Compare

    Compare --> Hysteresis
    Hysteresis --> State

    State --> Active
    State --> Inactive
    State --> Transition
```

---

## Pause Detection State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> Listening: start()
    Listening --> VoiceDetected: RMS > threshold

    VoiceDetected --> Speaking: sustained voice
    Speaking --> Speaking: continuous voice

    Speaking --> PauseDetecting: RMS < threshold
    PauseDetecting --> Speaking: voice resumes < 500ms

    PauseDetecting --> PauseConfirmed: silence >= 500ms
    PauseConfirmed --> SegmentComplete: emit final result

    SegmentComplete --> Listening: reset for new segment

    Listening --> Idle: stop()
    Speaking --> Idle: stop()
    PauseDetecting --> Idle: stop()
```

---

## Speaker Diarization Flow

```mermaid
flowchart TB
    subgraph Input[Audio Segment]
        Segment[Voice Segment]
    end

    subgraph Embedding[Voice Embedding]
        Extract[Extract Features<br/>MFCC, Pitch]
        Embed[Generate Embedding<br/>128-dim vector]
    end

    subgraph Clustering[Speaker Clustering]
        Compare[Compare to Known Speakers]
        Similarity[Cosine Similarity]
        Threshold[Threshold: 0.8]
    end

    subgraph Assignment[Speaker Assignment]
        Match[Match Existing]
        New[Create New Speaker]
        Label[Assign Label<br/>Speaker 0/1]
    end

    Segment --> Extract
    Extract --> Embed
    Embed --> Compare

    Compare --> Similarity
    Similarity --> Threshold

    Threshold -->|>=0.8| Match
    Threshold -->|<0.8| New

    Match --> Label
    New --> Label
```

---

## Audio Buffer Pool Management

```mermaid
flowchart TB
    subgraph Pool[Buffer Pool]
        Available[Available Buffers<br/>Pre-allocated]
        InUse[In-Use Buffers]
        MaxSize[Max Size: 10]
    end

    subgraph Acquire[Buffer Acquisition]
        Request[Request Buffer]
        Check[Check Availability]
        Allocate[Allocate New]
        Reuse[Reuse Existing]
    end

    subgraph Release[Buffer Release]
        Return[Return Buffer]
        Reset[Reset Frame Length]
        Add[Add to Pool]
        Discard[Discard if Full]
    end

    subgraph Threading[Thread Safety]
        Lock[NSLock]
        Sync[Synchronized Access]
    end

    Request --> Lock
    Lock --> Check
    Check -->|Available| Reuse
    Check -->|Empty| Allocate

    Return --> Lock
    Lock --> Reset
    Reset --> Check
    Check -->|Not Full| Add
    Check -->|Full| Discard
```

---

## TTS Audio Queue

```mermaid
flowchart TB
    subgraph Input[Text Input]
        Segment1[Segment 1]
        Segment2[Segment 2]
        Segment3[Segment 3]
    end

    subgraph Synthesis[Parallel Synthesis]
        Synth1[Synthesize 1]
        Synth2[Synthesize 2]
        Synth3[Synthesize 3]
    end

    subgraph Queue[Audio Queue]
        Buffer[Pre-buffer: 2 segments]
        Q1[Audio 1]
        Q2[Audio 2]
        Q3[Audio 3]
    end

    subgraph Playback[Playback Control]
        Player[Audio Player]
        Current[Currently Playing]
        Next[Next Up]
    end

    Segment1 --> Synth1 --> Q1
    Segment2 --> Synth2 --> Q2
    Segment3 --> Synth3 --> Q3

    Q1 --> Buffer
    Q2 --> Buffer
    Q3 --> Buffer

    Buffer --> Player
    Player --> Current
    Q2 --> Next
```

---

## Interruption Handling

```mermaid
flowchart TB
    subgraph Interruptions[Interruption Types]
        Phone[Phone Call]
        Siri[Siri Activation]
        Alarm[Alarm/Timer]
        Other[Other App Audio]
    end

    subgraph Detection[Detection]
        Notification[AVAudioSession Notification]
        Type[Interruption Type]
        Options[Options Flags]
    end

    subgraph Response[Response Actions]
        Pause[Pause Recognition]
        Save[Save State]
        Deactivate[Deactivate Session]
    end

    subgraph Recovery[Recovery]
        Resume[Resume Recognition]
        Restore[Restore State]
        Reactivate[Reactivate Session]
    end

    Phone --> Notification
    Siri --> Notification
    Alarm --> Notification
    Other --> Notification

    Notification --> Type
    Type --> Options

    Options -->|began| Pause
    Pause --> Save
    Save --> Deactivate

    Options -->|ended + shouldResume| Resume
    Resume --> Restore
    Restore --> Reactivate
```

---

## Audio Route Management

```mermaid
flowchart TB
    subgraph Devices[Audio Devices]
        BuiltIn[Built-in Mic/Speaker]
        Bluetooth[Bluetooth Headset]
        Wired[Wired Headphones]
        AirPlay[AirPlay]
    end

    subgraph Detection[Route Detection]
        Monitor[Route Change Monitor]
        Current[Current Route]
        Available[Available Routes]
    end

    subgraph Selection[Route Selection]
        Auto[Automatic Selection]
        Manual[Manual Override]
        Preference[User Preference]
    end

    subgraph Handling[Change Handling]
        Connected[Device Connected]
        Disconnected[Device Disconnected]
        Fallback[Fallback Route]
    end

    BuiltIn --> Available
    Bluetooth --> Available
    Wired --> Available
    AirPlay --> Available

    Available --> Monitor
    Monitor --> Current

    Current --> Auto
    Manual --> Current
    Preference --> Auto

    Monitor --> Connected
    Monitor --> Disconnected
    Disconnected --> Fallback
    Fallback --> Current
```

---

## Pipeline Performance Metrics

```mermaid
flowchart TB
    subgraph Metrics[Performance Metrics]
        Latency[End-to-End Latency<br/>Target: <1s]
        STTLatency[STT Latency<br/>Target: <300ms]
        TransLatency[Translation Latency<br/>Target: <500ms]
        TTSLatency[TTS Latency<br/>Target: <200ms]
    end

    subgraph Collection[Metric Collection]
        Timer[High-Precision Timer]
        Samples[Sample Collection<br/>Last 100]
        Stats[Statistics<br/>P50, P95, P99]
    end

    subgraph Monitoring[Monitoring]
        Dashboard[Performance Dashboard]
        Alerts[Latency Alerts]
        Logs[Performance Logs]
    end

    Latency --> Timer
    STTLatency --> Timer
    TransLatency --> Timer
    TTSLatency --> Timer

    Timer --> Samples
    Samples --> Stats

    Stats --> Dashboard
    Stats --> Alerts
    Stats --> Logs
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
