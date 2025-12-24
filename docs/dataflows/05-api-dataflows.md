# LiveLingo - API Communication Data Flows

## DF-API-001: CoeFont HMAC-SHA256 Authentication Flow

Cryptographic request signing for CoeFont API.

```mermaid
flowchart TB
    subgraph Input[Request Data]
        BODY_DATA[Request Body<br/>{coefont, text, speed, pitch}]
        ACCESS_KEY[Access Key<br/>from Keychain]
        SECRET_KEY[Secret Key<br/>from Keychain]
    end

    subgraph Preparation[Data Preparation]
        JSON_ENCODE[JSON Encode Body]
        BODY_STRING[Body as String]
        TIMESTAMP[Generate Timestamp<br/>Unix Epoch Seconds]
    end

    subgraph Signing[Signature Generation]
        CONCAT[Concatenate<br/>timestamp + bodyString]
        MESSAGE[Message to Sign]
        SYM_KEY[Create SymmetricKey<br/>from secret]
    end

    subgraph HMAC[HMAC Computation]
        COMPUTE[HMAC<SHA256>.authenticationCode]
        AUTH_CODE[Authentication Code<br/>32 bytes]
        HEX_ENCODE[Hex Encode<br/>64 characters]
        SIGNATURE[Final Signature]
    end

    subgraph Headers[Request Headers]
        H_AUTH[Authorization: accessKey]
        H_DATE[X-Coefont-Date: timestamp]
        H_CONTENT[X-Coefont-Content: signature]
        H_TYPE[Content-Type: application/json]
    end

    subgraph Request[Final Request]
        BUILD[Build URLRequest]
        SEND[Send to API]
    end

    BODY_DATA --> JSON_ENCODE
    JSON_ENCODE --> BODY_STRING

    BODY_STRING --> CONCAT
    TIMESTAMP --> CONCAT
    CONCAT --> MESSAGE

    SECRET_KEY --> SYM_KEY
    MESSAGE --> COMPUTE
    SYM_KEY --> COMPUTE

    COMPUTE --> AUTH_CODE
    AUTH_CODE --> HEX_ENCODE
    HEX_ENCODE --> SIGNATURE

    ACCESS_KEY --> H_AUTH
    TIMESTAMP --> H_DATE
    SIGNATURE --> H_CONTENT

    H_AUTH --> BUILD
    H_DATE --> BUILD
    H_CONTENT --> BUILD
    H_TYPE --> BUILD
    BODY_STRING --> BUILD

    BUILD --> SEND
```

---

## DF-API-002: Exponential Backoff Retry Flow

Failed request retry with increasing delays.

```mermaid
flowchart TB
    subgraph Initial[Initial Request]
        REQUEST[API Request]
        ATTEMPT[Attempt: 1]
    end

    subgraph Execute[Execute Request]
        SEND[Send Request]
        RESPONSE[Get Response]
    end

    subgraph Analyze[Response Analysis]
        CHECK{Response Status}
        SUCCESS[2xx Success]
        RETRYABLE[429, 5xx, Timeout]
        NON_RETRYABLE[4xx Client Error]
    end

    subgraph RetryLogic[Retry Logic]
        COUNT{Attempt < Max?<br/>Max: 4]
        CALC_DELAY[Calculate Delay<br/>min(1s * 2^attempt, 10s)]
    end

    subgraph Delays[Delay Schedule]
        D1[Attempt 1: 0s]
        D2[Attempt 2: 1s]
        D3[Attempt 3: 2s]
        D4[Attempt 4: 4s]
    end

    subgraph Wait[Wait Period]
        SLEEP[Sleep for Delay]
        INCREMENT[Increment Attempt]
    end

    subgraph Output[Final Output]
        RETURN_SUCCESS[Return Result]
        RETURN_ERROR[Return Error]
    end

    REQUEST --> ATTEMPT
    ATTEMPT --> SEND
    SEND --> RESPONSE

    RESPONSE --> CHECK
    CHECK --> SUCCESS
    CHECK --> RETRYABLE
    CHECK --> NON_RETRYABLE

    SUCCESS --> RETURN_SUCCESS
    NON_RETRYABLE --> RETURN_ERROR

    RETRYABLE --> COUNT
    COUNT -->|Yes| CALC_DELAY
    COUNT -->|No| RETURN_ERROR

    CALC_DELAY --> D1
    CALC_DELAY --> D2
    CALC_DELAY --> D3
    CALC_DELAY --> D4

    D1 --> SLEEP
    D2 --> SLEEP
    D3 --> SLEEP
    D4 --> SLEEP

    SLEEP --> INCREMENT
    INCREMENT --> SEND
```

---

## DF-API-003: Rate Limiter Flow

Request throttling per API endpoint.

```mermaid
flowchart TB
    subgraph Request[Incoming Request]
        API_REQ[API Request]
        HOST[Extract Host]
    end

    subgraph Limits[Rate Limit Configuration]
        CF_LIMIT[CoeFont: 100/min]
        OAI_LIMIT[OpenAI: 60/min]
        ANT_LIMIT[Anthropic: 60/min]
        WINDOW[Window: 60 seconds]
    end

    subgraph Tracking[Request Tracking]
        GET_BUCKET[Get/Create Token Bucket]
        CLEAN_OLD[Clean Requests > 60s]
        COUNT[Count Recent Requests]
    end

    subgraph Decision[Limit Decision]
        CHECK{Under Limit?}
        RECORD[Record Request Time]
        CALC_WAIT[Calculate Wait Time]
    end

    subgraph Queue[Request Queue]
        ENQUEUE[Enqueue Request]
        WAIT[Wait for Slot]
        DEQUEUE[Dequeue & Execute]
    end

    subgraph Execute[Request Execution]
        PROCEED[Proceed with Request]
        SEND[Send to API]
    end

    subgraph Response[Response Handling]
        RES_OK[Success]
        RES_429[429: Extract Retry-After]
        UPDATE[Update Rate Limit State]
    end

    API_REQ --> HOST
    HOST --> GET_BUCKET

    CF_LIMIT --> GET_BUCKET
    OAI_LIMIT --> GET_BUCKET
    ANT_LIMIT --> GET_BUCKET

    GET_BUCKET --> CLEAN_OLD
    CLEAN_OLD --> COUNT

    COUNT --> CHECK
    CHECK -->|Yes| RECORD
    CHECK -->|No| CALC_WAIT

    RECORD --> PROCEED
    CALC_WAIT --> ENQUEUE
    ENQUEUE --> WAIT
    WAIT --> DEQUEUE
    DEQUEUE --> PROCEED

    PROCEED --> SEND

    SEND --> RES_OK
    SEND --> RES_429

    RES_OK --> UPDATE
    RES_429 --> UPDATE
    RES_429 --> ENQUEUE
```

---

## DF-API-004: Network Reachability Monitor Flow

Connection state tracking.

```mermaid
flowchart TB
    subgraph Initialization[Monitor Initialization]
        CREATE[Create NWPathMonitor]
        QUEUE[Set Update Queue<br/>.main]
        START[Start Monitoring]
    end

    subgraph PathUpdate[Path Update Handler]
        CALLBACK[pathUpdateHandler]
        PATH[NWPath]
        STATUS[path.status]
        INTERFACE[path.availableInterfaces]
    end

    subgraph Analysis[Connection Analysis]
        CHECK_SATISFIED{status == .satisfied?}
        CHECK_TYPE[Check Interface Type]
        EXPENSIVE{isExpensive?}
        CONSTRAINED{isConstrained?}
    end

    subgraph States[Network States]
        ONLINE[Online]
        OFFLINE[Offline]
        WIFI[WiFi Connected]
        CELLULAR[Cellular Only]
        CONSTRAINED_STATE[Constrained Mode]
    end

    subgraph Publish[State Publication]
        UPDATE_STATE[Update Network State]
        NOTIFY[Notify Observers]
        UI_UPDATE[Update UI Indicator]
    end

    subgraph AppReaction[App Reactions]
        ENABLE_CLOUD[Enable Cloud Features]
        ENABLE_OFFLINE[Enable Offline Mode]
        REDUCE_QUALITY[Reduce Data Quality]
    end

    CREATE --> QUEUE
    QUEUE --> START
    START --> CALLBACK

    CALLBACK --> PATH
    PATH --> STATUS
    PATH --> INTERFACE

    STATUS --> CHECK_SATISFIED
    CHECK_SATISFIED -->|Yes| CHECK_TYPE
    CHECK_SATISFIED -->|No| OFFLINE

    CHECK_TYPE --> WIFI
    CHECK_TYPE --> CELLULAR

    WIFI --> EXPENSIVE
    CELLULAR --> EXPENSIVE
    EXPENSIVE -->|Yes| CONSTRAINED
    EXPENSIVE -->|No| ONLINE

    CONSTRAINED -->|Yes| CONSTRAINED_STATE
    CONSTRAINED -->|No| ONLINE

    ONLINE --> UPDATE_STATE
    OFFLINE --> UPDATE_STATE
    CONSTRAINED_STATE --> UPDATE_STATE

    UPDATE_STATE --> NOTIFY
    NOTIFY --> UI_UPDATE

    ONLINE --> ENABLE_CLOUD
    OFFLINE --> ENABLE_OFFLINE
    CONSTRAINED_STATE --> REDUCE_QUALITY
```

---

## DF-API-005: Request/Response Logging Flow

Sanitized logging for debugging.

```mermaid
flowchart TB
    subgraph Request[Outgoing Request]
        METHOD[HTTP Method]
        URL[Request URL]
        HEADERS[Request Headers]
        BODY[Request Body]
    end

    subgraph Sanitization[Sanitization]
        REMOVE_AUTH[Remove Authorization]
        REMOVE_KEYS[Remove API Keys]
        MASK_PII[Mask Personal Data]
        TRUNCATE[Truncate Large Bodies<br/>Max 1000 chars]
    end

    subgraph RequestLog[Request Logging]
        START_TIME[Record Start Time]
        LOG_REQ[Log Request Details]
        REQ_ID[Generate Request ID]
    end

    subgraph Execute[Execute Request]
        SEND[Send Request]
        RECEIVE[Receive Response]
    end

    subgraph Response[Response Data]
        STATUS[Status Code]
        RES_HEADERS[Response Headers]
        RES_BODY[Response Body]
        DURATION[Calculate Duration]
    end

    subgraph ResponseLog[Response Logging]
        LOG_RES[Log Response Details]
        LOG_DUR[Log Duration]
        LOG_SIZE[Log Response Size]
    end

    subgraph Output[Log Output]
        DEBUG[Debug Console]
        ANALYTICS[Analytics<br/>if enabled]
        FILE[Log File<br/>if enabled]
    end

    METHOD --> LOG_REQ
    URL --> LOG_REQ
    HEADERS --> REMOVE_AUTH
    BODY --> REMOVE_KEYS
    REMOVE_AUTH --> MASK_PII
    REMOVE_KEYS --> MASK_PII
    MASK_PII --> TRUNCATE
    TRUNCATE --> LOG_REQ

    LOG_REQ --> START_TIME
    START_TIME --> REQ_ID
    REQ_ID --> SEND

    SEND --> RECEIVE

    RECEIVE --> STATUS
    RECEIVE --> RES_HEADERS
    RECEIVE --> RES_BODY
    START_TIME --> DURATION

    STATUS --> LOG_RES
    RES_BODY --> TRUNCATE
    TRUNCATE --> LOG_RES
    DURATION --> LOG_DUR
    RES_BODY --> LOG_SIZE

    LOG_REQ --> DEBUG
    LOG_RES --> DEBUG
    LOG_DUR --> DEBUG
    LOG_SIZE --> DEBUG

    LOG_REQ --> ANALYTICS
    LOG_RES --> ANALYTICS
```

---

## DF-API-006: Certificate Pinning Flow

TLS certificate validation.

```mermaid
flowchart TB
    subgraph Connection[TLS Connection]
        CLIENT_HELLO[Client Hello]
        SERVER_CERT[Server Certificate]
        CHAIN[Certificate Chain]
    end

    subgraph Extraction[Certificate Extraction]
        GET_CHAIN[Get Certificate Chain]
        LEAF[Extract Leaf Cert]
        INTERMEDIATE[Extract Intermediate]
    end

    subgraph Hashing[Hash Computation]
        GET_KEY[Get Public Key]
        COMPUTE_HASH[Compute SHA-256]
        HASH_VALUE[Hash Value]
    end

    subgraph Pinning[Pin Comparison]
        LOAD_PINS[Load Pinned Hashes]
        CF_PIN[CoeFont Pin]
        OAI_PIN[OpenAI Pin]
        ANT_PIN[Anthropic Pin]
        BACKUP_PIN[Backup Pins]
    end

    subgraph Validation[Validation]
        COMPARE[Compare Hash to Pins]
        MATCH{Match Found?}
    end

    subgraph Decision[Connection Decision]
        ALLOW[Allow Connection]
        BLOCK[Block Connection<br/>Potential MITM]
        LOG_ALERT[Log Security Alert]
    end

    CLIENT_HELLO --> SERVER_CERT
    SERVER_CERT --> CHAIN

    CHAIN --> GET_CHAIN
    GET_CHAIN --> LEAF
    GET_CHAIN --> INTERMEDIATE

    LEAF --> GET_KEY
    GET_KEY --> COMPUTE_HASH
    COMPUTE_HASH --> HASH_VALUE

    LOAD_PINS --> CF_PIN
    LOAD_PINS --> OAI_PIN
    LOAD_PINS --> ANT_PIN
    LOAD_PINS --> BACKUP_PIN

    HASH_VALUE --> COMPARE
    CF_PIN --> COMPARE
    OAI_PIN --> COMPARE
    ANT_PIN --> COMPARE
    BACKUP_PIN --> COMPARE

    COMPARE --> MATCH
    MATCH -->|Yes| ALLOW
    MATCH -->|No| BLOCK
    BLOCK --> LOG_ALERT
```

---

## DF-API-007: OpenAI API Request Flow

Complete OpenAI API call lifecycle.

```mermaid
flowchart TB
    subgraph Input[Translation Input]
        TEXT[Source Text]
        CONTEXT[Context History]
        LANG_PAIR[Language Pair]
    end

    subgraph PromptBuild[Prompt Building]
        SYSTEM_MSG[System Message<br/>Interpreter Role]
        CONTEXT_MSG[Context Messages]
        USER_MSG[User Message<br/>Translation Request]
        MESSAGES[Messages Array]
    end

    subgraph RequestBuild[Request Building]
        MODEL[model: gpt-4o-mini]
        TEMP[temperature: 0.3]
        MAX_TOKENS[max_tokens: 1000]
        AUTH[Authorization: Bearer sk-xxx]
    end

    subgraph Network[Network Call]
        RATE_CHECK[Rate Limit Check]
        SEND[POST /v1/chat/completions]
        WAIT[Await Response]
    end

    subgraph Response[Response Processing]
        PARSE[Parse JSON]
        EXTRACT[Extract choices[0].message.content]
        VALIDATE[Validate Translation]
    end

    subgraph Output[Output]
        RESULT[Translation Result]
        UPDATE_CTX[Update Context]
        CACHE[Cache Result]
    end

    TEXT --> USER_MSG
    CONTEXT --> CONTEXT_MSG
    LANG_PAIR --> SYSTEM_MSG

    SYSTEM_MSG --> MESSAGES
    CONTEXT_MSG --> MESSAGES
    USER_MSG --> MESSAGES

    MESSAGES --> MODEL
    MODEL --> TEMP
    TEMP --> MAX_TOKENS
    MAX_TOKENS --> AUTH

    AUTH --> RATE_CHECK
    RATE_CHECK --> SEND
    SEND --> WAIT

    WAIT --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> VALIDATE

    VALIDATE --> RESULT
    RESULT --> UPDATE_CTX
    RESULT --> CACHE
```

---

## DF-API-008: Anthropic API Request Flow

Complete Anthropic API call lifecycle.

```mermaid
flowchart TB
    subgraph Input[Translation Input]
        TEXT[Source Text]
        CONTEXT[Context History]
        GLOSSARY[Active Glossary]
    end

    subgraph RequestBuild[Request Building]
        MODEL[model: claude-3-haiku-20240307]
        MAX_TOKENS[max_tokens: 1000]
        SYSTEM[system: Interpreter prompt]
        MESSAGES[messages: [...]]
    end

    subgraph Headers[Request Headers]
        API_KEY[x-api-key: sk-ant-xxx]
        VERSION[anthropic-version: 2023-06-01]
        CONTENT_TYPE[Content-Type: application/json]
    end

    subgraph Network[Network Call]
        BUILD[Build Request]
        SEND[POST /v1/messages]
        WAIT[Await Response]
    end

    subgraph Response[Response Processing]
        PARSE[Parse JSON]
        EXTRACT[Extract content[0].text]
        CLEAN[Clean Response]
    end

    subgraph Output[Output]
        RESULT[Translation Result]
        TOKENS[Usage: input/output tokens]
    end

    TEXT --> MESSAGES
    CONTEXT --> MESSAGES
    GLOSSARY --> SYSTEM

    MODEL --> BUILD
    MAX_TOKENS --> BUILD
    SYSTEM --> BUILD
    MESSAGES --> BUILD

    API_KEY --> BUILD
    VERSION --> BUILD
    CONTENT_TYPE --> BUILD

    BUILD --> SEND
    SEND --> WAIT

    WAIT --> PARSE
    PARSE --> EXTRACT
    EXTRACT --> CLEAN

    CLEAN --> RESULT
    PARSE --> TOKENS
```

---

## DF-API-009: API Error Response Handling Flow

HTTP error code processing.

```mermaid
flowchart TB
    subgraph Response[API Response]
        STATUS[HTTP Status Code]
        BODY[Response Body]
        HEADERS[Response Headers]
    end

    subgraph Classification[Error Classification]
        CHECK{Status Code}
        E400[400 Bad Request]
        E401[401 Unauthorized]
        E403[403 Forbidden]
        E404[404 Not Found]
        E429[429 Rate Limited]
        E500[500 Server Error]
        E503[503 Unavailable]
    end

    subgraph Mapping[Error Mapping]
        MAP_INVALID[InvalidRequest]
        MAP_AUTH[AuthenticationFailed]
        MAP_ACCESS[AccessDenied]
        MAP_NOT_FOUND[ResourceNotFound]
        MAP_RATE[RateLimited]
        MAP_SERVER[ServerError]
    end

    subgraph Actions[Recovery Actions]
        SHOW_ERROR[Show Error UI]
        RETRY[Retry with Backoff]
        REAUTH[Re-authenticate]
        FALLBACK[Use Fallback]
        QUEUE[Queue for Later]
    end

    STATUS --> CHECK

    CHECK --> E400
    CHECK --> E401
    CHECK --> E403
    CHECK --> E404
    CHECK --> E429
    CHECK --> E500
    CHECK --> E503

    E400 --> MAP_INVALID --> SHOW_ERROR
    E401 --> MAP_AUTH --> REAUTH
    E403 --> MAP_ACCESS --> SHOW_ERROR
    E404 --> MAP_NOT_FOUND --> SHOW_ERROR
    E429 --> MAP_RATE --> RETRY
    E500 --> MAP_SERVER --> RETRY
    E503 --> MAP_SERVER --> FALLBACK
```

---

## DF-API-010: Request Timeout Handling Flow

Timeout detection and recovery.

```mermaid
flowchart TB
    subgraph Request[Request Configuration]
        URL_REQ[URLRequest]
        TIMEOUT_INT[timeoutInterval: 30s]
    end

    subgraph Execute[Request Execution]
        SEND[Send Request]
        TIMER[Start Timer]
        WAIT[Wait for Response]
    end

    subgraph Monitor[Timeout Monitoring]
        CHECK{Response Received?}
        TIME_CHECK{Time > 30s?}
    end

    subgraph Timeout[Timeout Handling]
        CANCEL[Cancel Request]
        ERROR[NSError.timedOut]
        CLASSIFY[Classify as Retryable]
    end

    subgraph Recovery[Recovery Strategy]
        ATTEMPT{Retry Attempt}
        RETRY[Retry Request]
        SHORTER_TIMEOUT[Reduce Timeout<br/>for Retry]
        GIVE_UP[Return Timeout Error]
    end

    subgraph Alternative[Alternative Actions]
        CACHE[Check Cache]
        OFFLINE[Use Offline Mode]
        NOTIFY[Notify User]
    end

    URL_REQ --> TIMEOUT_INT
    TIMEOUT_INT --> SEND

    SEND --> TIMER
    TIMER --> WAIT

    WAIT --> CHECK
    CHECK -->|No| TIME_CHECK
    TIME_CHECK -->|Yes| CANCEL
    TIME_CHECK -->|No| WAIT

    CANCEL --> ERROR
    ERROR --> CLASSIFY

    CLASSIFY --> ATTEMPT
    ATTEMPT -->|< 3| RETRY
    ATTEMPT -->|>= 3| GIVE_UP

    RETRY --> SHORTER_TIMEOUT
    SHORTER_TIMEOUT --> SEND

    GIVE_UP --> CACHE
    CACHE --> OFFLINE
    OFFLINE --> NOTIFY
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation - 10 API data flows | AI Agent |
