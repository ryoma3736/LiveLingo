# LiveLingo - Translation Workflows

## WF-TRN-001: Apple Translation Framework

On-device translation using Apple's Translation API.

```mermaid
sequenceDiagram
    participant App as Application
    participant TM as TranslationManager
    participant Avail as LanguageAvailability
    participant Session as TranslationSession
    participant Cache as TranslationCache

    App->>TM: translate(text, source: ja, target: en)
    TM->>Cache: get(text, ja, en)

    alt Cache Hit
        Cache-->>TM: cachedTranslation
        TM-->>App: translation (from cache)
    else Cache Miss
        TM->>Avail: status(from: ja, to: en)

        alt Downloaded
            Avail-->>TM: .installed
            TM->>Session: TranslationSession(config)
            TM->>Session: translate(text)
            Session-->>TM: translatedText
            TM->>Cache: set(text, translation, ja, en)
            TM-->>App: translation
        else Not Downloaded
            Avail-->>TM: .notInstalled
            TM->>TM: fallbackToCloudLLM()
        end
    end
```

---

## WF-TRN-002: Cloud LLM Translation (OpenAI)

GPT-based translation with context support.

```mermaid
sequenceDiagram
    participant TM as TranslationManager
    participant Client as LLMAPIClient
    participant CTX as ContextManager
    participant Net as NetworkManager
    participant OAI as OpenAI API

    TM->>Client: translate(text, ja, en, context)
    Client->>CTX: getRecentContext(limit: 5)
    CTX-->>Client: [previousTurns]

    Client->>Client: buildPrompt(text, context)
    Note over Client: System: Professional interpreter<br/>User: Translate with context

    Client->>Net: checkConnectivity()
    Net-->>Client: isOnline: true

    Client->>OAI: POST /v1/chat/completions
    Note over OAI: model: gpt-4o-mini<br/>temperature: 0.3

    OAI-->>Client: {choices: [{message: {content: translation}}]}
    Client->>Client: extractTranslation()
    Client-->>TM: translatedText

    TM->>CTX: addTurn(original, translated)
```

---

## WF-TRN-003: Cloud LLM Translation (Anthropic)

Claude-based translation as alternative provider.

```mermaid
sequenceDiagram
    participant TM as TranslationManager
    participant Client as LLMAPIClient
    participant CTX as ContextManager
    participant ANT as Anthropic API

    TM->>Client: translate(text, ja, en, context)
    Client->>CTX: getRecentContext(limit: 5)
    CTX-->>Client: [previousTurns]

    Client->>Client: buildPrompt(text, context)

    Client->>ANT: POST /v1/messages
    Note over ANT: model: claude-3-haiku<br/>anthropic-version: 2023-06-01

    ANT-->>Client: {content: [{text: translation}]}
    Client->>Client: extractTranslation()
    Client-->>TM: translatedText
```

---

## WF-TRN-004: Wait-k Streaming Translation

Low-latency streaming using Wait-k algorithm.

```mermaid
sequenceDiagram
    participant STT as SpeechRecognitionManager
    participant Buffer as TokenBuffer
    participant Stream as StreamingTranslator
    participant TTS as TTSManager

    Note over Buffer: k = 3 (wait for 3 tokens)

    STT->>Buffer: token("Hello")
    Note over Buffer: buffer: ["Hello"]

    STT->>Buffer: token("how")
    Note over Buffer: buffer: ["Hello", "how"]

    STT->>Buffer: token("are")
    Note over Buffer: buffer: ["Hello", "how", "are"]<br/>k tokens reached!

    Buffer->>Stream: translateSegment(["Hello", "how", "are"])
    Stream-->>TTS: "Konnichiwa, ogenki"
    TTS->>TTS: synthesizeAndPlay()

    STT->>Buffer: token("you")
    STT->>Buffer: token("today")
    STT->>Buffer: token("?")
    Note over Buffer: buffer: ["you", "today", "?"]

    Buffer->>Stream: translateSegment(["you", "today", "?"])
    Stream-->>TTS: "desuka kyou wa?"

    Note over TTS: Seamless audio queue playback
```

---

## WF-TRN-005: Context-aware Translation

Multi-turn conversation context management.

```mermaid
sequenceDiagram
    participant TM as TranslationManager
    participant CTX as ContextManager
    participant Trans as Translator
    participant Memory as ShortTermMemory

    TM->>CTX: addContext(original, translated, speakerID)
    CTX->>Memory: store(turn)
    Memory->>Memory: maintainWindow(maxTurns: 10)

    Note over Memory: Rolling window of last 10 turns

    TM->>CTX: getContextForTranslation()
    CTX->>Memory: getRecentTurns(5)
    Memory-->>CTX: [turn1, turn2, turn3, turn4, turn5]

    CTX->>CTX: formatAsPromptContext()
    Note over CTX: - Speaker1: Hello -> Konnichiwa<br/>- Speaker2: Hi there -> Hai, konnichiwa<br/>...

    CTX-->>Trans: contextualPrompt

    Trans->>Trans: translate(newText, withContext)
    Note over Trans: Uses context for:<br/>- Pronoun resolution<br/>- Topic continuity<br/>- Style consistency
```

---

## WF-TRN-006: Glossary Application

Custom dictionary integration for specialized terms.

```mermaid
sequenceDiagram
    participant TM as TranslationManager
    participant Gloss as GlossaryManager
    participant Pre as Preprocessor
    participant Trans as Translator
    participant Post as Postprocessor

    TM->>Gloss: getActiveGlossary(sourceLang, targetLang)
    Gloss-->>TM: Glossary (entries: [...])

    TM->>Pre: preprocess(text, glossary)
    Pre->>Pre: findMatches(text, entries)

    loop For each match
        Pre->>Pre: mark term with placeholder
        Note over Pre: "API" -> "<<TERM_1>>"
    end

    Pre-->>Trans: preprocessedText, termMap

    Trans->>Trans: translate(preprocessedText)
    Trans-->>Post: translatedText

    Post->>Post: restoreTerms(translatedText, termMap)
    Note over Post: "<<TERM_1>>" -> glossary[API].targetText

    Post-->>TM: finalTranslation
```

---

## Translation Provider Selection

```mermaid
flowchart TD
    A[Translation Request] --> B{Check Cache}
    B -->|Hit| C[Return Cached]
    B -->|Miss| D{Check Network}

    D -->|Offline| E{Apple Translation<br/>Available?}
    E -->|Yes| F[Use Apple Translation]
    E -->|No| G[Return Error:<br/>No Offline Support]

    D -->|Online| H{User Preference}
    H -->|On-device| I{Apple Translation<br/>Language Pair Available?}
    I -->|Yes| F
    I -->|No| J[Use Cloud LLM]

    H -->|Cloud| J

    J --> K{Provider Selection}
    K -->|OpenAI| L[Use GPT-4o-mini]
    K -->|Anthropic| M[Use Claude-3-haiku]

    F --> N[Cache Result]
    L --> N
    M --> N

    N --> O[Return Translation]
```

---

## Translation Quality Comparison

```mermaid
sequenceDiagram
    participant Test as BenchmarkTest
    participant Apple as AppleTranslation
    participant OpenAI as OpenAI API
    participant Claude as Anthropic API
    participant Eval as QualityEvaluator

    Test->>Test: loadTestSentences()

    loop For each test sentence
        par Parallel Translation
            Test->>Apple: translate(sentence)
            Apple-->>Test: appleResult
            and
            Test->>OpenAI: translate(sentence)
            OpenAI-->>Test: openaiResult
            and
            Test->>Claude: translate(sentence)
            Claude-->>Test: claudeResult
        end

        Test->>Eval: evaluate(reference, results)
        Eval->>Eval: calculateBLEU()
        Eval->>Eval: measureLatency()
        Eval-->>Test: scores
    end

    Test->>Test: generateReport()
    Note over Test: Compare accuracy, latency, cost
```

---

## Translation State Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> CheckingCache: translate()
    CheckingCache --> Returning: cache hit
    CheckingCache --> CheckingNetwork: cache miss

    Returning --> Idle: complete

    CheckingNetwork --> SelectingProvider: online
    CheckingNetwork --> UsingOnDevice: offline

    SelectingProvider --> UsingApple: prefer on-device
    SelectingProvider --> UsingCloud: prefer cloud

    UsingOnDevice --> Translating: Apple available
    UsingOnDevice --> Error: Apple unavailable

    UsingApple --> Translating: start
    UsingCloud --> Translating: start

    Translating --> Caching: success
    Translating --> Retrying: transient error
    Translating --> Error: permanent error

    Retrying --> Translating: retry
    Retrying --> Error: max retries

    Caching --> Returning: cached

    Error --> Idle: error handled
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
