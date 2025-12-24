# LiveLingo - Translation Engine Data Flows

## DF-TRN-001: Provider Selection Flow

Translation provider routing logic.

```mermaid
flowchart TB
    subgraph Input[Translation Request]
        TEXT[Source Text]
        SRC[Source Language]
        TGT[Target Language]
        PREF[User Preference]
    end

    subgraph CacheCheck[Cache Layer]
        CACHE_KEY[Generate Cache Key<br/>src:tgt:hash(text)]
        CACHE_LOOKUP[Lookup Cache]
        HIT{Cache Hit?}
    end

    subgraph NetworkCheck[Network Check]
        NET_STATUS[Check Network]
        ONLINE{Online?}
    end

    subgraph OfflinePath[Offline Path]
        APPLE_AVAIL{Apple Trans<br/>Available?}
        APPLE_TRANS[Apple Translation<br/>On-device]
        OFFLINE_ERR[Offline Error<br/>No Support]
    end

    subgraph OnlinePath[Online Path]
        USER_PREF{User Preference}
        ON_DEVICE[Prefer On-device]
        CLOUD[Prefer Cloud]
    end

    subgraph CloudProvider[Cloud Provider Selection]
        PROVIDER_PREF{Provider Setting}
        OPENAI[OpenAI<br/>GPT-4o-mini]
        ANTHROPIC[Anthropic<br/>Claude-3-haiku]
    end

    subgraph Output[Result Output]
        RESULT[Translation Result]
        CACHE_STORE[Store in Cache]
    end

    TEXT --> CACHE_KEY
    SRC --> CACHE_KEY
    TGT --> CACHE_KEY
    CACHE_KEY --> CACHE_LOOKUP

    CACHE_LOOKUP --> HIT
    HIT -->|Yes| RESULT

    HIT -->|No| NET_STATUS
    NET_STATUS --> ONLINE

    ONLINE -->|No| APPLE_AVAIL
    APPLE_AVAIL -->|Yes| APPLE_TRANS
    APPLE_AVAIL -->|No| OFFLINE_ERR

    ONLINE -->|Yes| USER_PREF
    PREF --> USER_PREF

    USER_PREF --> ON_DEVICE
    USER_PREF --> CLOUD

    ON_DEVICE --> APPLE_AVAIL
    CLOUD --> PROVIDER_PREF

    PROVIDER_PREF --> OPENAI
    PROVIDER_PREF --> ANTHROPIC

    APPLE_TRANS --> CACHE_STORE
    OPENAI --> CACHE_STORE
    ANTHROPIC --> CACHE_STORE

    CACHE_STORE --> RESULT
```

---

## DF-TRN-002: Apple Translation On-Device Flow

Native translation framework usage.

```mermaid
flowchart TB
    subgraph Request[Translation Request]
        TEXT[Source Text]
        SRC_LANG[Source: ja-JP]
        TGT_LANG[Target: en-US]
    end

    subgraph Availability[Language Availability]
        CHECK_AVAIL[Check Availability]
        STATUS[LanguageAvailability.Status]
        INSTALLED{.installed?}
        NOT_INSTALLED{.notInstalled?}
    end

    subgraph Download[Language Download]
        DOWNLOAD_PROMPT[Prompt Download]
        DOWNLOAD_PROG[Download Progress]
        DOWNLOAD_COMPLETE[Download Complete]
    end

    subgraph Session[Translation Session]
        CREATE_CONFIG[Create Configuration<br/>source, target]
        CREATE_SESSION[TranslationSession]
        PREPARE[Prepare Session]
    end

    subgraph Translate[Translation Execution]
        SEND[Send Text]
        PROCESS[Process On-device]
        RECEIVE[Receive Translation]
    end

    subgraph Output[Result]
        TRANSLATED[Translated Text]
        ERROR[Translation Error]
    end

    TEXT --> CHECK_AVAIL
    SRC_LANG --> CHECK_AVAIL
    TGT_LANG --> CHECK_AVAIL

    CHECK_AVAIL --> STATUS
    STATUS --> INSTALLED
    STATUS --> NOT_INSTALLED

    NOT_INSTALLED -->|Yes| DOWNLOAD_PROMPT
    DOWNLOAD_PROMPT --> DOWNLOAD_PROG
    DOWNLOAD_PROG --> DOWNLOAD_COMPLETE
    DOWNLOAD_COMPLETE --> INSTALLED

    INSTALLED -->|Yes| CREATE_CONFIG
    CREATE_CONFIG --> CREATE_SESSION
    CREATE_SESSION --> PREPARE

    PREPARE --> SEND
    TEXT --> SEND
    SEND --> PROCESS
    PROCESS --> RECEIVE

    RECEIVE --> TRANSLATED
    PROCESS -->|Error| ERROR
```

---

## DF-TRN-003: OpenAI GPT Translation Flow

Cloud translation via OpenAI API.

```mermaid
flowchart TB
    subgraph Request[Translation Request]
        TEXT[Source Text]
        CONTEXT[Conversation Context<br/>Last 5 turns]
        SRC[Source Language]
        TGT[Target Language]
    end

    subgraph PromptBuilding[Prompt Construction]
        SYSTEM[System Prompt<br/>Professional Interpreter]
        CONTEXT_FORMAT[Format Context<br/>Previous translations]
        USER_MSG[User Message<br/>Current text to translate]
    end

    subgraph APIRequest[API Request]
        BUILD_REQ[Build Request Body]
        MODEL[model: gpt-4o-mini]
        PARAMS[temperature: 0.3<br/>max_tokens: 1000]
        HEADERS[Authorization: Bearer]
    end

    subgraph Network[Network Call]
        SEND[POST /v1/chat/completions]
        WAIT[Await Response]
    end

    subgraph Response[Response Handling]
        PARSE[Parse JSON Response]
        EXTRACT[Extract content<br/>choices[0].message.content]
        CLEAN[Clean Translation]
    end

    subgraph Output[Result]
        TRANSLATION[Translated Text]
        UPDATE_CTX[Update Context Manager]
    end

    TEXT --> USER_MSG
    CONTEXT --> CONTEXT_FORMAT
    SRC --> SYSTEM
    TGT --> SYSTEM

    SYSTEM --> BUILD_REQ
    CONTEXT_FORMAT --> BUILD_REQ
    USER_MSG --> BUILD_REQ
    MODEL --> BUILD_REQ
    PARAMS --> BUILD_REQ
    HEADERS --> BUILD_REQ

    BUILD_REQ --> SEND
    SEND --> WAIT

    WAIT --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> CLEAN

    CLEAN --> TRANSLATION
    TRANSLATION --> UPDATE_CTX
```

---

## DF-TRN-004: Anthropic Claude Translation Flow

Cloud translation via Anthropic API.

```mermaid
flowchart TB
    subgraph Request[Translation Request]
        TEXT[Source Text]
        CONTEXT[Conversation Context]
        GLOSSARY[Active Glossary]
    end

    subgraph PromptBuilding[Prompt Construction]
        SYSTEM_PROMPT[System:<br/>Professional interpreter prompt]
        MESSAGES[Messages Array]
        CONTEXT_MSG[Context Messages<br/>Previous turns]
        CURRENT_MSG[Current Translation Request]
    end

    subgraph APIRequest[API Request]
        BUILD_REQ[Build Request Body]
        MODEL[model: claude-3-haiku-20240307]
        PARAMS[max_tokens: 1000]
        HEADERS[x-api-key<br/>anthropic-version: 2023-06-01]
    end

    subgraph Network[Network Call]
        SEND[POST /v1/messages]
        WAIT[Await Response]
    end

    subgraph Response[Response Handling]
        PARSE[Parse JSON Response]
        EXTRACT[Extract content[0].text]
        POST_PROCESS[Post-process]
    end

    subgraph Output[Result]
        TRANSLATION[Translated Text]
    end

    TEXT --> CURRENT_MSG
    CONTEXT --> CONTEXT_MSG
    GLOSSARY --> SYSTEM_PROMPT

    SYSTEM_PROMPT --> BUILD_REQ
    CONTEXT_MSG --> MESSAGES
    CURRENT_MSG --> MESSAGES
    MESSAGES --> BUILD_REQ
    MODEL --> BUILD_REQ
    PARAMS --> BUILD_REQ
    HEADERS --> BUILD_REQ

    BUILD_REQ --> SEND
    SEND --> WAIT

    WAIT --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> POST_PROCESS

    POST_PROCESS --> TRANSLATION
```

---

## DF-TRN-005: Context-Aware Translation Flow

Multi-turn context management for coherent translation.

```mermaid
flowchart TB
    subgraph NewTurn[New Turn Input]
        ORIGINAL[Original Text]
        TRANSLATED[Translated Text]
        SPEAKER[Speaker ID]
        TIMESTAMP[Timestamp]
    end

    subgraph ContextManager[Context Manager]
        STORE[Store Turn]
        WINDOW[Rolling Window<br/>Max 10 turns]
        TRIM[Trim Oldest]
    end

    subgraph Retrieval[Context Retrieval]
        GET_RECENT[Get Recent N Turns]
        FORMAT[Format for LLM]
    end

    subgraph PromptAugmentation[Prompt Augmentation]
        BASE_PROMPT[Base System Prompt]
        ADD_CONTEXT[Add Context History]
        FINAL_PROMPT[Augmented Prompt]
    end

    subgraph Translation[Translation with Context]
        SEND_LLM[Send to LLM]
        RECEIVE[Receive Translation]
    end

    subgraph ContextBenefits[Context Benefits]
        PRONOUN[Pronoun Resolution<br/>he/she/it → proper noun]
        TOPIC[Topic Continuity]
        STYLE[Style Consistency]
        DOMAIN[Domain Vocabulary]
    end

    ORIGINAL --> STORE
    TRANSLATED --> STORE
    SPEAKER --> STORE
    TIMESTAMP --> STORE

    STORE --> WINDOW
    WINDOW --> TRIM

    WINDOW --> GET_RECENT
    GET_RECENT --> FORMAT

    BASE_PROMPT --> ADD_CONTEXT
    FORMAT --> ADD_CONTEXT
    ADD_CONTEXT --> FINAL_PROMPT

    FINAL_PROMPT --> SEND_LLM
    SEND_LLM --> RECEIVE

    RECEIVE --> PRONOUN
    RECEIVE --> TOPIC
    RECEIVE --> STYLE
    RECEIVE --> DOMAIN
```

---

## DF-TRN-006: Glossary Application Flow

Custom dictionary term handling.

```mermaid
flowchart TB
    subgraph Input[Translation Input]
        TEXT[Source Text<br/>API連携について説明します]
    end

    subgraph GlossaryLoad[Glossary Loading]
        GET_GLOSSARY[Get Active Glossary]
        ENTRIES[Glossary Entries<br/>API → Application Programming Interface]
    end

    subgraph Preprocessing[Preprocessing]
        SCAN[Scan for Matches]
        FOUND{Terms Found?}
        MARK[Mark with Placeholders<br/><<TERM_1>>]
        TERM_MAP[Build Term Map]
    end

    subgraph Translation[Translation]
        TRANSLATE[Translate Preprocessed<br/><<TERM_1>>連携について説明します]
        RESULT[Translation Result<br/>I'll explain about <<TERM_1>> integration]
    end

    subgraph Postprocessing[Postprocessing]
        RESTORE[Restore Terms]
        LOOKUP[Lookup in Term Map]
        REPLACE[Replace Placeholders]
    end

    subgraph Output[Final Output]
        FINAL[Final Translation<br/>I'll explain about Application Programming Interface integration]
    end

    TEXT --> GET_GLOSSARY
    GET_GLOSSARY --> ENTRIES

    TEXT --> SCAN
    ENTRIES --> SCAN
    SCAN --> FOUND

    FOUND -->|Yes| MARK
    FOUND -->|No| TRANSLATE

    MARK --> TERM_MAP
    MARK --> TRANSLATE

    TRANSLATE --> RESULT
    RESULT --> RESTORE
    TERM_MAP --> LOOKUP
    LOOKUP --> REPLACE

    REPLACE --> FINAL
```

---

## DF-TRN-007: Translation Cache Flow

Multi-tier caching for performance.

```mermaid
flowchart TB
    subgraph Request[Cache Request]
        KEY[Cache Key<br/>src:tgt:hash]
    end

    subgraph MemoryCache[Memory Cache L1]
        MEM_LOOKUP[Memory Lookup]
        MEM_HIT{Hit?}
        MEM_GET[Get from Memory]
    end

    subgraph DiskCache[Disk Cache L2]
        DISK_LOOKUP[Disk Lookup]
        DISK_HIT{Hit?}
        DISK_GET[Get from Disk]
        LOAD_TO_MEM[Load to Memory]
    end

    subgraph APIFetch[API Fetch]
        TRANSLATE[Call Translation API]
        RESULT[Translation Result]
    end

    subgraph CacheStore[Cache Storage]
        STORE_MEM[Store in Memory]
        STORE_DISK[Store on Disk]
    end

    subgraph Expiration[Expiration Check]
        CHECK_TTL[Check TTL<br/>1 hour]
        EXPIRED{Expired?}
        INVALIDATE[Invalidate Entry]
    end

    subgraph Eviction[Cache Eviction]
        CHECK_SIZE[Check Cache Size<br/>Max 1000]
        FULL{Full?}
        LRU[Evict LRU 25%]
    end

    KEY --> MEM_LOOKUP
    MEM_LOOKUP --> MEM_HIT

    MEM_HIT -->|Yes| CHECK_TTL
    CHECK_TTL --> EXPIRED
    EXPIRED -->|No| MEM_GET
    EXPIRED -->|Yes| INVALIDATE
    INVALIDATE --> DISK_LOOKUP

    MEM_HIT -->|No| DISK_LOOKUP
    DISK_LOOKUP --> DISK_HIT

    DISK_HIT -->|Yes| DISK_GET
    DISK_GET --> LOAD_TO_MEM
    LOAD_TO_MEM --> STORE_MEM

    DISK_HIT -->|No| TRANSLATE
    TRANSLATE --> RESULT

    RESULT --> CHECK_SIZE
    CHECK_SIZE --> FULL
    FULL -->|Yes| LRU
    LRU --> STORE_MEM
    FULL -->|No| STORE_MEM

    STORE_MEM --> STORE_DISK
```

---

## DF-TRN-008: Wait-k Streaming Translation Flow

Low-latency streaming with token buffering.

```mermaid
flowchart TB
    subgraph TokenInput[Token Input Stream]
        STT_STREAM[STT Token Stream]
        T1[Token 1]
        T2[Token 2]
        T3[Token 3]
    end

    subgraph Buffer[Wait-k Buffer]
        K_CONFIG[k = 3 tokens]
        BUFFER_STATE[Buffer State]
        COUNT{count >= k?}
    end

    subgraph SegmentTranslation[Segment Translation]
        EXTRACT[Extract Segment]
        TRANSLATE[Translate Segment]
        SEGMENT_RESULT[Segment Translation]
    end

    subgraph OutputQueue[Output Queue]
        QUEUE[Translation Queue]
        EMIT[Emit to TTS]
    end

    subgraph Continuation[Stream Continuation]
        RESET[Reset Buffer]
        CONTINUE[Continue Buffering]
    end

    STT_STREAM --> T1
    STT_STREAM --> T2
    STT_STREAM --> T3

    T1 --> BUFFER_STATE
    T2 --> BUFFER_STATE
    T3 --> BUFFER_STATE

    K_CONFIG --> COUNT
    BUFFER_STATE --> COUNT

    COUNT -->|Yes| EXTRACT
    COUNT -->|No| CONTINUE

    EXTRACT --> TRANSLATE
    TRANSLATE --> SEGMENT_RESULT
    SEGMENT_RESULT --> QUEUE
    QUEUE --> EMIT

    EXTRACT --> RESET
    RESET --> CONTINUE
```

---

## DF-TRN-009: Translation Error Recovery Flow

Error handling with fallback chain.

```mermaid
flowchart TB
    subgraph Error[Error Types]
        NETWORK_ERR[Network Error]
        API_ERR[API Error]
        RATE_LIMIT[Rate Limit 429]
        TIMEOUT[Timeout]
        INVALID[Invalid Response]
    end

    subgraph Assessment[Error Assessment]
        CLASSIFY[Classify Error]
        RETRYABLE{Retryable?}
    end

    subgraph Retry[Retry Logic]
        ATTEMPT[Attempt Count]
        MAX{Max Attempts?}
        BACKOFF[Exponential Backoff<br/>1s, 2s, 4s, 8s]
        RETRY_REQ[Retry Request]
    end

    subgraph Fallback[Fallback Chain]
        TRY_APPLE[Try Apple Translation]
        TRY_OPENAI[Try OpenAI]
        TRY_ANTHROPIC[Try Anthropic]
        CACHE_SIMILAR[Check Similar Cache]
    end

    subgraph Recovery[Recovery Actions]
        SUCCESS[Success]
        DEGRADED[Degraded Response]
        FAIL[Return Error]
    end

    NETWORK_ERR --> CLASSIFY
    API_ERR --> CLASSIFY
    RATE_LIMIT --> CLASSIFY
    TIMEOUT --> CLASSIFY
    INVALID --> CLASSIFY

    CLASSIFY --> RETRYABLE

    RETRYABLE -->|Yes| ATTEMPT
    RETRYABLE -->|No| CACHE_SIMILAR

    ATTEMPT --> MAX
    MAX -->|No| BACKOFF
    BACKOFF --> RETRY_REQ
    RETRY_REQ --> SUCCESS
    RETRY_REQ --> ATTEMPT

    MAX -->|Yes| TRY_APPLE
    TRY_APPLE --> TRY_OPENAI
    TRY_OPENAI --> TRY_ANTHROPIC
    TRY_ANTHROPIC --> CACHE_SIMILAR

    TRY_APPLE --> SUCCESS
    TRY_OPENAI --> SUCCESS
    TRY_ANTHROPIC --> SUCCESS
    CACHE_SIMILAR --> DEGRADED
    CACHE_SIMILAR --> FAIL
```

---

## DF-TRN-010: Translation Quality Evaluation Flow

Quality metrics and provider comparison.

```mermaid
flowchart TB
    subgraph TestInput[Test Input]
        TEST_SET[Test Sentences]
        REFERENCE[Reference Translations]
    end

    subgraph ParallelTranslation[Parallel Translation]
        APPLE[Apple Translation]
        OPENAI[OpenAI GPT-4o-mini]
        ANTHROPIC[Anthropic Claude]
    end

    subgraph Results[Translation Results]
        RES_APPLE[Apple Result]
        RES_OPENAI[OpenAI Result]
        RES_ANTHROPIC[Anthropic Result]
    end

    subgraph Evaluation[Quality Evaluation]
        BLEU[BLEU Score]
        METEOR[METEOR Score]
        LATENCY[Latency Measurement]
        COST[Cost per Token]
    end

    subgraph Aggregation[Score Aggregation]
        COMBINE[Combine Scores]
        RANK[Rank Providers]
    end

    subgraph Output[Evaluation Output]
        REPORT[Quality Report]
        RECOMMENDATION[Provider Recommendation]
    end

    TEST_SET --> APPLE
    TEST_SET --> OPENAI
    TEST_SET --> ANTHROPIC

    APPLE --> RES_APPLE
    OPENAI --> RES_OPENAI
    ANTHROPIC --> RES_ANTHROPIC

    RES_APPLE --> BLEU
    RES_OPENAI --> BLEU
    RES_ANTHROPIC --> BLEU
    REFERENCE --> BLEU

    RES_APPLE --> METEOR
    RES_OPENAI --> METEOR
    RES_ANTHROPIC --> METEOR

    RES_APPLE --> LATENCY
    RES_OPENAI --> LATENCY
    RES_ANTHROPIC --> LATENCY

    RES_APPLE --> COST
    RES_OPENAI --> COST
    RES_ANTHROPIC --> COST

    BLEU --> COMBINE
    METEOR --> COMBINE
    LATENCY --> COMBINE
    COST --> COMBINE

    COMBINE --> RANK
    RANK --> REPORT
    RANK --> RECOMMENDATION
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 10 translation data flows | AI Agent |
