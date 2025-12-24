# LiveLingo - Network & API Architecture

## API Integration Overview

```mermaid
flowchart TB
    subgraph App[LiveLingo App]
        subgraph Clients[API Clients]
            CFC[CoeFontAPIClient]
            OAC[OpenAIAPIClient]
            ANC[AnthropicAPIClient]
            GSC[GoogleSpeechClient]
        end

        subgraph Core[Network Core]
            NM[NetworkManager]
            RL[RateLimiter]
            RH[RetryHandler]
            AM[AuthMiddleware]
        end
    end

    subgraph External[External APIs]
        subgraph CoeFont[CoeFont API]
            CF1[/v2/text2speech]
            CF2[/v2/voices]
        end

        subgraph OpenAI[OpenAI API]
            OA1[/v1/chat/completions]
        end

        subgraph Anthropic[Anthropic API]
            AN1[/v1/messages]
        end

        subgraph Google[Google Cloud API]
            GS1[/v1/speech:recognize]
        end
    end

    CFC --> NM
    OAC --> NM
    ANC --> NM
    GSC --> NM

    NM --> AM
    AM --> RL
    RL --> RH

    RH --> CF1
    RH --> CF2
    RH --> OA1
    RH --> AN1
    RH --> GS1
```

---

## CoeFont API Authentication (HMAC-SHA256)

```mermaid
flowchart TB
    subgraph Request[Request Building]
        Body[Request Body<br/>{coefont, text, speed, pitch}]
        Time[Timestamp<br/>Unix Epoch]
    end

    subgraph Signing[Signature Generation]
        Concat[Concatenate<br/>timestamp + body]
        HMAC[HMAC-SHA256<br/>secret key]
        Hex[Hex Encode]
    end

    subgraph Headers[Request Headers]
        H1[Authorization: accessKey]
        H2[X-Coefont-Date: timestamp]
        H3[X-Coefont-Content: signature]
        H4[Content-Type: application/json]
    end

    subgraph Send[Send Request]
        POST[POST /v2/text2speech]
    end

    Body --> Concat
    Time --> Concat
    Concat --> HMAC
    HMAC --> Hex
    Hex --> H3

    Time --> H2
    H1 --> POST
    H2 --> POST
    H3 --> POST
    H4 --> POST
    Body --> POST
```

---

## OpenAI API Integration

```mermaid
flowchart TB
    subgraph Request[Request Structure]
        Model[model: gpt-4o-mini]
        Messages[messages array]
        Params[temperature: 0.3<br/>max_tokens: 1000]
    end

    subgraph MessageFormat[Messages]
        System[role: system<br/>Professional interpreter prompt]
        Context[role: user<br/>Previous context]
        Current[role: user<br/>Current text to translate]
    end

    subgraph Auth[Authentication]
        Bearer[Authorization: Bearer sk-xxx]
    end

    subgraph Response[Response Handling]
        Parse[Parse JSON]
        Extract[Extract content]
        Return[Return translation]
    end

    Model --> Request
    Messages --> Request
    Params --> Request

    System --> Messages
    Context --> Messages
    Current --> Messages

    Bearer --> Request
    Request --> Parse
    Parse --> Extract
    Extract --> Return
```

---

## Anthropic API Integration

```mermaid
flowchart TB
    subgraph Request[Request Structure]
        Model[model: claude-3-haiku-20240307]
        MaxTokens[max_tokens: 1000]
        System[system: Interpreter prompt]
        Messages[messages array]
    end

    subgraph Headers[Required Headers]
        Auth[x-api-key: sk-ant-xxx]
        Version[anthropic-version: 2023-06-01]
        Content[Content-Type: application/json]
    end

    subgraph Response[Response Structure]
        ContentArray[content array]
        TextBlock[type: text<br/>text: translation]
    end

    Model --> Request
    MaxTokens --> Request
    System --> Request
    Messages --> Request

    Auth --> Headers
    Version --> Headers
    Content --> Headers

    Request --> ContentArray
    ContentArray --> TextBlock
```

---

## Rate Limiting Architecture

```mermaid
flowchart TB
    subgraph Limits[Rate Limits by API]
        CFLimit[CoeFont<br/>100 req/minute]
        OALimit[OpenAI<br/>60 req/minute]
        ANLimit[Anthropic<br/>60 req/minute]
        GSLimit[Google<br/>300 req/minute]
    end

    subgraph Limiter[Rate Limiter]
        Bucket[Token Bucket]
        Window[Sliding Window]
        Counter[Request Counter]
    end

    subgraph Handling[Limit Handling]
        Check[Check Limit]
        Queue[Queue Request]
        Wait[Wait for Slot]
        Execute[Execute Request]
    end

    subgraph Response[429 Response]
        RetryAfter[Retry-After Header]
        Backoff[Exponential Backoff]
    end

    CFLimit --> Bucket
    OALimit --> Bucket
    ANLimit --> Bucket
    GSLimit --> Bucket

    Bucket --> Check
    Check -->|Under Limit| Execute
    Check -->|At Limit| Queue
    Queue --> Wait
    Wait --> Execute

    Execute -->|429| RetryAfter
    RetryAfter --> Backoff
    Backoff --> Wait
```

---

## Retry Strategy

```mermaid
flowchart TB
    subgraph Request[Initial Request]
        Attempt1[Attempt 1]
    end

    subgraph Retry[Retry Logic]
        Check[Check Error Type]
        Retryable{Retryable?}
        MaxRetries{Max Retries?}
        Delay[Calculate Delay]
        Wait[Wait]
    end

    subgraph Delays[Exponential Backoff]
        D1[Attempt 1: 0s]
        D2[Attempt 2: 1s]
        D3[Attempt 3: 2s]
        D4[Attempt 4: 4s]
        D5[Max: 10s]
    end

    subgraph Errors[Error Types]
        Retry429[429 Rate Limited]
        Retry5xx[5xx Server Error]
        RetryTimeout[Timeout]
        NoRetry4xx[4xx Client Error]
    end

    subgraph Result[Final Result]
        Success[Success]
        Failure[Failure]
    end

    Attempt1 --> Check
    Check --> Retryable

    Retryable -->|Yes| MaxRetries
    Retryable -->|No| Failure

    MaxRetries -->|No| Delay
    MaxRetries -->|Yes| Failure

    Delay --> Wait
    Wait --> Attempt1

    Retry429 --> Retryable
    Retry5xx --> Retryable
    RetryTimeout --> Retryable
    NoRetry4xx --> Failure

    Check -->|Success| Success
```

---

## Network Monitoring

```mermaid
flowchart TB
    subgraph Monitor[Network Monitor]
        NW[NWPathMonitor]
        Status[Connection Status]
        Type[Connection Type]
    end

    subgraph States[Network States]
        Connected[Connected]
        Disconnected[Disconnected]
        Cellular[Cellular Only]
        WiFi[WiFi]
        Constrained[Constrained]
    end

    subgraph Reactions[App Reactions]
        Online[Enable Cloud Features]
        Offline[Enable Offline Mode]
        LowData[Reduce Quality]
    end

    subgraph Features[Feature Availability]
        CloudTrans[Cloud Translation]
        CoeFont[CoeFont TTS]
        Sync[iCloud Sync]
        AppleTrans[Apple Translation]
        AppleTTS[Apple TTS]
    end

    NW --> Status
    NW --> Type

    Status --> Connected
    Status --> Disconnected
    Type --> Cellular
    Type --> WiFi
    Type --> Constrained

    Connected --> Online
    Disconnected --> Offline
    Constrained --> LowData

    Online --> CloudTrans
    Online --> CoeFont
    Online --> Sync
    Offline --> AppleTrans
    Offline --> AppleTTS
```

---

## API Error Handling

```mermaid
flowchart TB
    subgraph Errors[HTTP Error Codes]
        E400[400 Bad Request]
        E401[401 Unauthorized]
        E403[403 Forbidden]
        E404[404 Not Found]
        E429[429 Rate Limited]
        E500[500 Server Error]
        E503[503 Unavailable]
    end

    subgraph Mapping[Error Mapping]
        Map[Error Mapper]
    end

    subgraph AppErrors[App Error Types]
        InvalidRequest[InvalidRequest]
        AuthFailed[AuthenticationFailed]
        AccessDenied[AccessDenied]
        NotFound[ResourceNotFound]
        RateLimited[RateLimited]
        ServerError[ServerError]
    end

    subgraph Handling[Error Handling]
        ShowError[Show Error UI]
        Retry[Retry Request]
        Fallback[Use Fallback]
        Reauthenticate[Re-authenticate]
    end

    E400 --> Map --> InvalidRequest --> ShowError
    E401 --> Map --> AuthFailed --> Reauthenticate
    E403 --> Map --> AccessDenied --> ShowError
    E404 --> Map --> NotFound --> ShowError
    E429 --> Map --> RateLimited --> Retry
    E500 --> Map --> ServerError --> Retry
    E503 --> Map --> ServerError --> Fallback
```

---

## Request/Response Logging

```mermaid
flowchart TB
    subgraph Request[Outgoing Request]
        Method[HTTP Method]
        URL[Request URL]
        Headers[Headers<br/>Sanitized]
        Body[Body<br/>Sanitized]
    end

    subgraph Logger[Request Logger]
        LogRequest[Log Request]
        Timer[Start Timer]
    end

    subgraph Response[Incoming Response]
        Status[Status Code]
        ResHeaders[Response Headers]
        ResBody[Response Body<br/>Truncated]
        Duration[Request Duration]
    end

    subgraph Output[Log Output]
        Debug[Debug Console]
        Analytics[Analytics<br/>if enabled]
    end

    subgraph Sanitize[Sanitization]
        RemoveKeys[Remove API Keys]
        TruncateBody[Truncate Large Bodies]
        MaskPII[Mask Personal Data]
    end

    Method --> LogRequest
    URL --> LogRequest
    Headers --> Sanitize
    Body --> Sanitize
    Sanitize --> LogRequest
    LogRequest --> Timer

    Status --> LogRequest
    ResHeaders --> LogRequest
    ResBody --> Sanitize
    Timer --> Duration
    Duration --> LogRequest

    LogRequest --> Debug
    LogRequest --> Analytics
```

---

## Certificate Pinning

```mermaid
flowchart TB
    subgraph Connection[TLS Connection]
        ClientHello[Client Hello]
        ServerCert[Server Certificate]
    end

    subgraph Verification[Certificate Verification]
        ExtractChain[Extract Cert Chain]
        ComputeHash[Compute SHA-256 Hash]
        Compare[Compare with Pins]
    end

    subgraph Pins[Pinned Certificates]
        CoePin[CoeFont API Pin]
        OAPin[OpenAI API Pin]
        ANPin[Anthropic API Pin]
        Backup[Backup Pins]
    end

    subgraph Decision[Connection Decision]
        Allow[Allow Connection]
        Block[Block Connection<br/>Potential MITM]
    end

    ClientHello --> ServerCert
    ServerCert --> ExtractChain
    ExtractChain --> ComputeHash

    ComputeHash --> Compare
    CoePin --> Compare
    OAPin --> Compare
    ANPin --> Compare
    Backup --> Compare

    Compare -->|Match| Allow
    Compare -->|No Match| Block
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
