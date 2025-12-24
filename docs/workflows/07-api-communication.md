# LiveLingo - API Communication Workflows

## WF-API-001: CoeFont HMAC-SHA256 Authentication

Signed API request with HMAC-SHA256.

```mermaid
sequenceDiagram
    participant Client as CoeFontAPIClient
    participant Crypto as CryptoKit
    participant Net as URLSession
    participant API as CoeFont API

    Client->>Client: createRequestBody()
    Note over Client: {coefont, text, speed, pitch}

    Client->>Client: timestamp = String(Date().timeIntervalSince1970)

    Client->>Crypto: generateSignature(timestamp, bodyString)

    Crypto->>Crypto: message = timestamp + bodyString
    Crypto->>Crypto: key = SymmetricKey(data: clientSecret)
    Crypto->>Crypto: signature = HMAC<SHA256>.authenticationCode(for: message, using: key)
    Crypto->>Crypto: hexString = signature.map{String(format:"%02x",$0)}.joined()

    Crypto-->>Client: signatureHex

    Client->>Client: buildRequest()
    Note over Client: Headers:<br/>Authorization: accessKey<br/>X-Coefont-Date: timestamp<br/>X-Coefont-Content: signature<br/>Content-Type: application/json

    Client->>Net: URLSession.data(for: request)
    Net->>API: POST /v2/text2speech

    alt Valid Signature
        API-->>Net: 200 OK + audioData
        Net-->>Client: (data, response)
        Client-->>Client: return audioData
    else Invalid Signature
        API-->>Net: 401 Unauthorized
        Net-->>Client: error
        Client-->>Client: throw authenticationFailed
    end
```

---

## WF-API-002: Retry with Exponential Backoff

Failed request retry strategy.

```mermaid
sequenceDiagram
    participant Client as APIClient
    participant Retry as RetryHandler
    participant Net as NetworkManager
    participant API as External API

    Client->>Retry: execute(operation)

    loop Attempt 1..maxRetries
        Retry->>Net: performRequest()
        Net->>API: HTTP Request

        alt Success (2xx)
            API-->>Net: response
            Net-->>Retry: success
            Retry-->>Client: result
        else Retryable Error (429, 5xx, timeout)
            API-->>Net: error
            Net-->>Retry: error

            Retry->>Retry: shouldRetry(error, attempt)

            alt Attempt < maxRetries
                Retry->>Retry: calculateDelay()
                Note over Retry: delay = min(baseDelay * 2^attempt, maxDelay)<br/>baseDelay: 1s, maxDelay: 10s

                Retry->>Retry: sleep(delay)
                Note over Retry: Attempt 1: 1s<br/>Attempt 2: 2s<br/>Attempt 3: 4s
            else Max Retries Reached
                Retry-->>Client: throw lastError
            end
        else Non-Retryable Error (4xx)
            API-->>Net: error
            Net-->>Retry: error
            Retry-->>Client: throw error
        end
    end
```

---

## WF-API-003: Rate Limit Handling

Request throttling and queuing.

```mermaid
sequenceDiagram
    participant Client as APIClient
    participant Limiter as RateLimiter
    participant Queue as RequestQueue
    participant API as External API

    Client->>Limiter: checkLimit(url)
    Limiter->>Limiter: getHost(url)
    Note over Limiter: host: api.coefont.cloud<br/>limit: 100 req/60s

    Limiter->>Limiter: cleanOldRequests(60s)
    Limiter->>Limiter: countRequests()

    alt Under Limit
        Limiter->>Limiter: recordRequest(now)
        Limiter-->>Client: proceed
        Client->>API: send request
    else At Limit
        Limiter->>Limiter: calculateWaitTime()
        Note over Limiter: waitTime = window - (now - oldestRequest)

        alt Wait Time > 0
            Limiter-->>Client: throw rateLimited
            Client->>Queue: enqueue(request)

            Queue->>Queue: wait(waitTime)
            Queue->>Limiter: checkLimit(url)
            Limiter-->>Queue: proceed
            Queue->>API: send request
        else Slot Available
            Limiter-->>Client: proceed
            Client->>API: send request
        end
    end
```

---

## WF-API-004: Offline Detection

Network state monitoring and handling.

```mermaid
sequenceDiagram
    participant App as Application
    participant Net as NetworkManager
    participant Reach as NetworkReachability
    participant NW as NWPathMonitor
    participant UI as OfflineIndicator

    App->>Net: initialize()
    Net->>Reach: startMonitoring()
    Reach->>NW: NWPathMonitor()
    NW->>NW: start(queue: .main)

    loop Monitor Network
        NW->>Reach: pathUpdateHandler(path)

        alt path.status == .satisfied
            Reach->>Net: updateStatus(.connected)
            Net->>Net: isOnline = true
            Net->>UI: hideOfflineIndicator()
        else path.status == .unsatisfied
            Reach->>Net: updateStatus(.disconnected)
            Net->>Net: isOnline = false
            Net->>UI: showOfflineIndicator()
        end
    end

    Note over App: API Request Attempted

    App->>Net: execute(request)
    Net->>Net: check isOnline

    alt Online
        Net->>Net: proceed with request
    else Offline
        Net-->>App: throw NetworkError.offline
        App->>App: handleOfflineError()
        App->>App: queueForLater()
    end
```

---

## WF-API-005: Response Caching

Translation cache management.

```mermaid
sequenceDiagram
    participant TM as TranslationManager
    participant Cache as TranslationCache
    participant Lock as NSLock
    participant API as TranslationAPI

    TM->>Cache: get(text, source, target)

    Cache->>Lock: lock()
    Cache->>Cache: key = "\(source):\(target):\(text.hashValue)"
    Cache->>Cache: lookup(key)

    alt Cache Hit
        Cache->>Cache: checkExpiration()

        alt Not Expired (< 1 hour)
            Cache->>Cache: entry.hitCount += 1
            Cache->>Lock: unlock()
            Cache-->>TM: cachedTranslation
        else Expired
            Cache->>Cache: remove(key)
            Cache->>Lock: unlock()
            Cache-->>TM: nil (cache miss)
        end
    else Cache Miss
        Cache->>Lock: unlock()
        Cache-->>TM: nil

        TM->>API: translate(text)
        API-->>TM: translation

        TM->>Cache: set(text, translation, source, target)
        Cache->>Lock: lock()

        alt Cache Full (>= 1000 entries)
            Cache->>Cache: evictLRU()
            Note over Cache: Remove 25% least used entries
        end

        Cache->>Cache: store(key, entry)
        Cache->>Lock: unlock()
    end
```

---

## API Client Architecture

```mermaid
flowchart TD
    subgraph Application
        VM[ViewModel]
    end

    subgraph NetworkLayer[Network Layer]
        NM[NetworkManager]
        Auth[AuthManager]
        RL[RateLimiter]
        RH[RetryHandler]
    end

    subgraph APIClients[API Clients]
        CF[CoeFontClient]
        GS[GoogleSpeechClient]
        OAI[OpenAIClient]
        ANT[AnthropicClient]
    end

    subgraph External[External APIs]
        CFE[CoeFont API]
        GSE[Google API]
        OAIE[OpenAI API]
        ANTE[Anthropic API]
    end

    VM --> CF
    VM --> GS
    VM --> OAI
    VM --> ANT

    CF --> NM
    GS --> NM
    OAI --> NM
    ANT --> NM

    NM --> Auth
    NM --> RL
    NM --> RH

    CF --> CFE
    GS --> GSE
    OAI --> OAIE
    ANT --> ANTE
```

---

## Error Response Handling

```mermaid
sequenceDiagram
    participant Client as APIClient
    participant Net as NetworkManager
    participant Validator as ResponseValidator
    participant Handler as ErrorHandler
    participant UI as UserInterface

    Client->>Net: execute(request)
    Net-->>Client: (data, response)

    Client->>Validator: validate(response, data)
    Validator->>Validator: checkStatusCode()

    alt 200-299 Success
        Validator-->>Client: valid
        Client->>Client: decodeResponse()
        Client-->>UI: success result
    else 401 Unauthorized
        Validator-->>Handler: unauthorized
        Handler->>Handler: refreshToken()

        alt Token Refreshed
            Handler->>Net: retry(request)
        else Refresh Failed
            Handler->>UI: promptReauthentication()
        end
    else 403 Forbidden
        Validator-->>Handler: forbidden
        Handler->>UI: showAccessDenied()
    else 404 Not Found
        Validator-->>Handler: notFound
        Handler->>UI: showResourceNotFound()
    else 429 Rate Limited
        Validator-->>Handler: rateLimited
        Handler->>Handler: extractRetryAfter()
        Handler->>UI: showRateLimitMessage()
    else 500-599 Server Error
        Validator-->>Handler: serverError
        Handler->>Handler: scheduleRetry()
        Handler->>UI: showTemporaryError()
    end
```

---

## Network State Diagram

```mermaid
stateDiagram-v2
    [*] --> Unknown

    Unknown --> Checking: startMonitoring()
    Checking --> Online: path.satisfied
    Checking --> Offline: path.unsatisfied

    Online --> Offline: connection lost
    Offline --> Online: connection restored

    Online --> Requesting: send request
    Requesting --> Success: 2xx response
    Requesting --> Retrying: retryable error
    Requesting --> Failed: non-retryable error

    Retrying --> Requesting: delay elapsed
    Retrying --> Failed: max retries

    Success --> Online: complete
    Failed --> Online: error handled

    Offline --> Queuing: request attempted
    Queuing --> Requesting: connection restored
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
