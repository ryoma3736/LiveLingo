# LiveLingo - Security & Privacy Workflows

## WF-SEC-001: Keychain Access

Secure credential storage and retrieval.

```mermaid
sequenceDiagram
    participant App as Application
    participant KM as KeychainManager
    participant Sec as Security Framework
    participant Keychain as iOS Keychain

    Note over App: Storing API Key

    App->>KM: save(string: apiKey, forKey: "coefont_api_key")

    KM->>KM: data = apiKey.data(using: .utf8)

    KM->>KM: buildQuery()
    Note over KM: kSecClass: kSecClassGenericPassword<br/>kSecAttrAccount: "coefont_api_key"<br/>kSecValueData: data<br/>kSecAttrAccessible: whenUnlockedThisDeviceOnly

    KM->>Sec: SecItemDelete(query)
    Note over Sec: Remove existing item if any

    KM->>Sec: SecItemAdd(query, nil)

    alt Success (errSecSuccess)
        Sec->>Keychain: store encrypted
        Sec-->>KM: status = 0
        KM-->>App: saved
    else Failure
        Sec-->>KM: status = errorCode
        KM-->>App: throw KeychainError.saveFailed
    end

    Note over App: Retrieving API Key

    App->>KM: getString(forKey: "coefont_api_key")

    KM->>KM: buildRetrieveQuery()
    Note over KM: kSecReturnData: true<br/>kSecMatchLimit: kSecMatchLimitOne

    KM->>Sec: SecItemCopyMatching(query, &result)

    alt Item Found
        Sec->>Keychain: decrypt and return
        Keychain-->>Sec: data
        Sec-->>KM: result = data
        KM->>KM: String(data: result, encoding: .utf8)
        KM-->>App: apiKey
    else Item Not Found
        Sec-->>KM: errSecItemNotFound
        KM-->>App: nil
    end
```

---

## WF-SEC-002: Data Encryption

AES-256-GCM encryption for sensitive data.

```mermaid
sequenceDiagram
    participant App as Application
    participant EM as EncryptionManager
    participant KM as KeychainManager
    participant Crypto as CryptoKit
    participant Store as SwiftData

    Note over App: Encrypting Conversation Data

    App->>EM: encrypt(conversationData)

    EM->>EM: getOrCreateEncryptionKey()

    EM->>KM: getData(forKey: "encryption_key")

    alt Key Exists
        KM-->>EM: keyData
        EM->>EM: key = SymmetricKey(data: keyData)
    else Key Not Found
        EM->>Crypto: SymmetricKey(size: .bits256)
        Crypto-->>EM: newKey

        EM->>KM: save(data: keyData, forKey: "encryption_key")
        KM-->>EM: saved
    end

    EM->>Crypto: AES.GCM.seal(data, using: key)
    Note over Crypto: Generates random nonce<br/>Encrypts with AES-256-GCM<br/>Produces authentication tag

    Crypto-->>EM: sealedBox

    EM->>EM: combinedData = sealedBox.combined
    Note over EM: nonce + ciphertext + tag

    EM-->>App: encryptedData

    App->>Store: save(encryptedData)

    Note over App: Decrypting Data

    App->>EM: decrypt(encryptedData)

    EM->>EM: getEncryptionKey()
    EM->>Crypto: AES.GCM.SealedBox(combined: data)
    EM->>Crypto: AES.GCM.open(sealedBox, using: key)

    alt Decryption Success
        Crypto-->>EM: decryptedData
        EM-->>App: originalData
    else Decryption Failed
        Crypto-->>EM: error
        EM-->>App: throw EncryptionError.decryptionFailed
    end
```

---

## WF-SEC-003: Permission Request

Microphone and speech recognition permission flow.

```mermaid
sequenceDiagram
    participant App as Application
    participant PM as PermissionManager
    participant Audio as AVAudioSession
    participant Speech as SFSpeechRecognizer
    participant UI as PermissionUI
    participant User

    App->>PM: requestAllPermissions()

    PM->>Audio: recordPermission

    alt Undetermined
        PM->>UI: showMicrophoneRationale()
        UI->>User: "LiveLingo needs microphone access<br/>to hear your speech"

        User->>UI: Tap "Continue"

        PM->>Audio: requestRecordPermission()
        Audio->>User: System Permission Dialog
        User->>Audio: Allow / Don't Allow
        Audio-->>PM: granted / denied

    else Denied
        PM->>UI: showSettingsPrompt(.microphone)
        UI->>User: "Microphone access required.<br/>Open Settings?"

        User->>UI: Tap "Open Settings"
        PM->>PM: UIApplication.openSettings()
    else Granted
        Note over PM: Microphone already allowed
    end

    PM->>Speech: authorizationStatus()

    alt Not Determined
        PM->>UI: showSpeechRationale()
        UI->>User: "Speech recognition needed<br/>for real-time transcription"

        User->>UI: Tap "Continue"

        PM->>Speech: requestAuthorization()
        Speech->>User: System Permission Dialog
        User->>Speech: Allow / Don't Allow
        Speech-->>PM: authorized / denied

    else Denied or Restricted
        PM->>UI: showSettingsPrompt(.speechRecognition)
    else Authorized
        Note over PM: Speech recognition already allowed
    end

    PM-->>App: allPermissionsResult
```

---

## WF-SEC-004: Data Deletion

Privacy-compliant data removal.

```mermaid
sequenceDiagram
    participant User
    participant UI as PrivacySettingsView
    participant PM as PrivacyManager
    participant Data as DataManager
    participant Cache as CacheManager
    participant KM as KeychainManager
    participant Cloud as iCloud

    User->>UI: Tap "Delete All Data"

    UI->>UI: showDeleteConfirmation()
    Note over UI: "This will permanently delete<br/>all conversations and settings."

    User->>UI: Confirm Delete

    UI->>PM: deleteAllData()

    PM->>PM: beginDeletionProcess()

    par Parallel Deletion
        PM->>Data: deleteAllConversations()
        Data->>Data: fetchAllConversations()
        Data->>Data: modelContext.delete(each)
        Data->>Data: modelContext.save()
        Data-->>PM: conversationsDeleted
        and
        PM->>Cache: clearAll()
        Cache->>Cache: translationCache.removeAll()
        Cache->>Cache: audioCache.removeAll()
        Cache-->>PM: cachesCleared
        and
        PM->>KM: deleteNonEssential()
        Note over KM: Keep: Apple User ID<br/>Delete: encryption key, tokens
        KM-->>PM: keychainCleaned
    end

    PM->>Cloud: deleteFromiCloud()
    Cloud->>Cloud: remove synced records
    Cloud-->>PM: cloudDataDeleted

    PM->>PM: resetUserDefaults()
    Note over PM: Clear all app preferences<br/>except onboarding_complete

    PM-->>UI: deletionComplete

    UI->>User: "All data has been deleted"
    UI->>UI: navigateToWelcome()
```

---

## Security Architecture

```mermaid
flowchart TD
    subgraph DataAtRest[Data at Rest]
        A1[Conversations] -->|AES-256-GCM| A2[Encrypted SwiftData]
        A3[API Keys] -->|System Encryption| A4[Keychain]
        A5[User Settings] -->|Unencrypted| A6[UserDefaults]
    end

    subgraph DataInTransit[Data in Transit]
        B1[API Requests] -->|TLS 1.3| B2[External APIs]
        B3[iCloud Sync] -->|Apple Encryption| B4[CloudKit]
    end

    subgraph Authentication[Authentication]
        C1[Sign in with Apple]
        C2[Face ID / Touch ID]
        C3[Session Tokens]
    end

    subgraph Privacy[Privacy Controls]
        D1[Permission Manager]
        D2[Data Minimization]
        D3[Auto-Delete Settings]
    end

    A4 --> C3
    C1 --> A4
    C2 --> A4
```

---

## Certificate Pinning Flow

```mermaid
sequenceDiagram
    participant App as URLSession
    participant Delegate as CertificatePinningDelegate
    participant Trust as SecTrust
    participant Pins as PinnedHashes

    App->>Delegate: didReceive(challenge)

    Delegate->>Delegate: extractServerTrust()
    Delegate->>Trust: SecTrustCopyCertificateChain()
    Trust-->>Delegate: [certificates]

    loop For each certificate
        Delegate->>Delegate: calculateHash(certificate)
        Note over Delegate: SHA256(certificateData)

        Delegate->>Pins: contains(hash)?

        alt Hash Matches
            Pins-->>Delegate: true
            Delegate->>App: useCredential(trust)
            Note over App: Connection allowed
        end
    end

    alt No Match Found
        Delegate->>App: cancelAuthenticationChallenge()
        Note over App: Connection blocked<br/>Possible MITM attack
    end
```

---

## Audit Logging

```mermaid
sequenceDiagram
    participant Action as Security Action
    participant Logger as SecurityLogger
    participant Filter as SensitiveFilter
    participant Storage as LogStorage
    participant Export as ExportService

    Action->>Logger: log(event: .authSuccess, details)

    Logger->>Filter: sanitize(details)
    Filter->>Filter: removeKeys(["password", "apiKey", "token"])
    Filter-->>Logger: safeDetails

    Logger->>Logger: createLogEntry()
    Note over Logger: timestamp (ISO8601)<br/>event type<br/>sanitized details

    Logger->>Storage: append(entry)

    alt Debug Build
        Logger->>Logger: print to console
    end

    opt Export Logs
        Logger->>Export: exportLogs(range: last7Days)
        Export->>Export: formatAsJSON()
        Export->>Export: compressData()
        Export-->>Logger: exportedFile
    end
```

---

## Security State Diagram

```mermaid
stateDiagram-v2
    [*] --> Unauthenticated

    Unauthenticated --> Authenticating: sign in requested
    Authenticating --> Authenticated: success
    Authenticating --> Unauthenticated: failed

    Authenticated --> BiometricLocked: require biometric
    BiometricLocked --> Authenticated: biometric success
    BiometricLocked --> BiometricLocked: biometric failed

    Authenticated --> SessionExpired: token expired
    SessionExpired --> Authenticating: refresh token
    SessionExpired --> Unauthenticated: refresh failed

    Authenticated --> Unauthenticated: sign out

    state Authenticated {
        [*] --> Normal
        Normal --> AccessingSecureData: request secure data
        AccessingSecureData --> Decrypting: data encrypted
        Decrypting --> Normal: access complete
    }
```

---

## Privacy Compliance Checklist

```mermaid
flowchart LR
    subgraph GDPR[GDPR Compliance]
        G1[Right to Access]
        G2[Right to Erasure]
        G3[Data Portability]
        G4[Consent Management]
    end

    subgraph Implementation[Implementation]
        I1[Export Function] --> G1
        I1 --> G3
        I2[Delete All Data] --> G2
        I3[Privacy Settings] --> G4
    end

    subgraph Controls[User Controls]
        C1[View Data]
        C2[Delete Data]
        C3[Export Data]
        C4[Manage Permissions]
    end

    I1 --> C1
    I1 --> C3
    I2 --> C2
    I3 --> C4
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
