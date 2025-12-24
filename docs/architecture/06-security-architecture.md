# LiveLingo - Security Architecture

## Security Layers Overview

```mermaid
flowchart TB
    subgraph Layer1[Application Layer]
        Input[Input Validation]
        Output[Output Sanitization]
        Session[Session Management]
    end

    subgraph Layer2[Authentication Layer]
        Apple[Sign in with Apple]
        Biometric[Face ID / Touch ID]
        Token[Session Tokens]
    end

    subgraph Layer3[Authorization Layer]
        RBAC[Role-Based Access]
        Permission[Permission Checks]
        Scope[Feature Scopes]
    end

    subgraph Layer4[Data Protection Layer]
        Encrypt[AES-256-GCM Encryption]
        Keychain[Keychain Storage]
        TLS[TLS 1.3 Transport]
    end

    subgraph Layer5[Platform Security]
        Sandbox[App Sandbox]
        Entitlements[Entitlements]
        CodeSign[Code Signing]
    end

    Layer1 --> Layer2
    Layer2 --> Layer3
    Layer3 --> Layer4
    Layer4 --> Layer5
```

---

## Authentication Architecture

```mermaid
flowchart TB
    subgraph AuthMethods[Authentication Methods]
        subgraph Primary[Primary Auth]
            SIWA[Sign in with Apple]
            OAuth[OAuth 2.0 Flow]
        end

        subgraph Secondary[Secondary Auth]
            FaceID[Face ID]
            TouchID[Touch ID]
            Passcode[Device Passcode]
        end
    end

    subgraph Flow[Auth Flow]
        Request[Auth Request]
        Verify[Verification]
        Token[Token Generation]
        Store[Secure Storage]
    end

    subgraph State[Auth State]
        Anon[Anonymous]
        Authenticated[Authenticated]
        Locked[Biometric Locked]
        Expired[Session Expired]
    end

    SIWA --> Request
    FaceID --> Request
    TouchID --> Request

    Request --> Verify
    Verify -->|Success| Token
    Token --> Store

    Store --> Authenticated
    Anon --> Request
    Authenticated --> Locked
    Locked --> Authenticated
    Authenticated --> Expired
    Expired --> Request
```

---

## Encryption Architecture

```mermaid
flowchart TB
    subgraph KeyManagement[Key Management]
        Master[Master Key<br/>256-bit AES]
        Derived[Derived Keys<br/>Per-data-type]
        Rotation[Key Rotation]
    end

    subgraph Storage[Key Storage]
        Keychain[(Keychain<br/>Secure Enclave)]
        Access[Access Control<br/>BiometryCurrentSet]
    end

    subgraph Encryption[Encryption Process]
        Plain[Plaintext Data]
        Nonce[Random Nonce<br/>12 bytes]
        AESGCM[AES-256-GCM]
        Cipher[Ciphertext + Tag]
    end

    subgraph DataTypes[Protected Data]
        Conversations[Conversations]
        APIKeys[API Keys]
        Tokens[Session Tokens]
        Personal[Personal Data]
    end

    Master --> Keychain
    Keychain --> Access
    Master --> Derived

    Plain --> AESGCM
    Nonce --> AESGCM
    Derived --> AESGCM
    AESGCM --> Cipher

    Conversations --> Plain
    APIKeys --> Plain
    Tokens --> Plain
    Personal --> Plain
```

---

## Keychain Security Model

```mermaid
flowchart TB
    subgraph Items[Keychain Items]
        UserID[Apple User ID<br/>kSecClassGenericPassword]
        Session[Session Token<br/>kSecClassGenericPassword]
        EncKey[Encryption Key<br/>kSecClassKey]
        APIKey[API Keys<br/>kSecClassGenericPassword]
    end

    subgraph Access[Access Controls]
        WhenUnlocked[kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        BioCurrent[kSecAccessControlBiometryCurrentSet]
        BioAny[kSecAccessControlBiometryAny]
    end

    subgraph Protection[Protection Classes]
        Class1[Available when unlocked]
        Class2[Requires current biometry]
        Class3[Device-only, no backup]
    end

    UserID --> WhenUnlocked --> Class1
    Session --> WhenUnlocked --> Class1
    EncKey --> BioCurrent --> Class2
    APIKey --> BioCurrent --> Class2

    Class1 --> Class3
    Class2 --> Class3
```

---

## Permission Model

```mermaid
flowchart TB
    subgraph Permissions[iOS Permissions]
        Mic[Microphone<br/>NSMicrophoneUsageDescription]
        Speech[Speech Recognition<br/>NSSpeechRecognitionUsageDescription]
        Network[Network Access<br/>NSAppTransportSecurity]
    end

    subgraph Request[Permission Request Flow]
        Check[Check Status]
        Prompt[Show Rationale]
        System[System Dialog]
        Handle[Handle Result]
    end

    subgraph States[Permission States]
        NotDet[Not Determined]
        Granted[Granted]
        Denied[Denied]
        Restricted[Restricted]
    end

    subgraph Recovery[Recovery Actions]
        Settings[Open Settings]
        Degrade[Graceful Degradation]
        Block[Block Feature]
    end

    Mic --> Check
    Speech --> Check
    Network --> Check

    Check --> NotDet --> Prompt
    Prompt --> System
    System --> Handle

    Handle --> Granted
    Handle --> Denied
    Handle --> Restricted

    Denied --> Settings
    Denied --> Degrade
    Restricted --> Block
```

---

## Network Security

```mermaid
flowchart TB
    subgraph Transport[Transport Security]
        TLS13[TLS 1.3<br/>Minimum Version]
        PFS[Perfect Forward Secrecy]
        Cipher[Strong Cipher Suites]
    end

    subgraph Pinning[Certificate Pinning]
        Leaf[Leaf Certificate]
        Public[Public Key]
        Backup[Backup Pins]
    end

    subgraph ATS[App Transport Security]
        HTTPS[Require HTTPS]
        Exception[No Exceptions]
        PList[Info.plist Config]
    end

    subgraph Validation[Request Validation]
        Sign[Request Signing<br/>HMAC-SHA256]
        Timestamp[Timestamp Validation]
        Nonce[Replay Prevention]
    end

    Transport --> TLS13
    Transport --> PFS
    Transport --> Cipher

    Pinning --> Leaf
    Pinning --> Public
    Pinning --> Backup

    ATS --> HTTPS
    ATS --> Exception
    ATS --> PList

    Validation --> Sign
    Validation --> Timestamp
    Validation --> Nonce
```

---

## Data Protection Levels

```mermaid
flowchart LR
    subgraph Sensitive[Highly Sensitive]
        S1[API Keys]
        S2[Encryption Keys]
        S3[Auth Tokens]
    end

    subgraph Moderate[Moderately Sensitive]
        M1[Conversations]
        M2[User Preferences]
        M3[Voice Recordings]
    end

    subgraph Low[Low Sensitivity]
        L1[UI State]
        L2[Cache Data]
        L3[Analytics]
    end

    subgraph Protection[Protection Measures]
        P1[Keychain + Biometric]
        P2[AES-256-GCM]
        P3[Standard Storage]
    end

    S1 --> P1
    S2 --> P1
    S3 --> P1

    M1 --> P2
    M2 --> P2
    M3 --> P2

    L1 --> P3
    L2 --> P3
    L3 --> P3
```

---

## Privacy Architecture

```mermaid
flowchart TB
    subgraph Principles[Privacy Principles]
        Minimize[Data Minimization]
        Purpose[Purpose Limitation]
        Consent[User Consent]
        Transparency[Transparency]
    end

    subgraph Controls[User Controls]
        Export[Export Data]
        Delete[Delete All Data]
        Manage[Manage Permissions]
        History[Clear History]
    end

    subgraph Compliance[Compliance]
        GDPR[GDPR Rights]
        CCPA[CCPA Compliance]
        AppPrivacy[App Privacy Report]
    end

    subgraph Implementation[Implementation]
        LocalProcess[On-device Processing]
        NoTrack[No User Tracking]
        OptIn[Opt-in Analytics]
        AutoDelete[Auto-delete Old Data]
    end

    Minimize --> LocalProcess
    Purpose --> NoTrack
    Consent --> OptIn
    Transparency --> AppPrivacy

    Export --> GDPR
    Delete --> GDPR
    Delete --> CCPA
    Manage --> CCPA
```

---

## Security Audit Logging

```mermaid
flowchart TB
    subgraph Events[Security Events]
        AuthSuccess[Auth Success]
        AuthFail[Auth Failure]
        PermChange[Permission Change]
        DataAccess[Sensitive Data Access]
        Error[Security Error]
    end

    subgraph Logger[Security Logger]
        Filter[Sensitive Data Filter]
        Format[Log Formatting]
        Timestamp[Timestamp (ISO8601)]
    end

    subgraph Storage[Log Storage]
        Local[Local Log File<br/>Last 1000 entries]
        Rotate[Log Rotation]
    end

    subgraph Privacy[Privacy Protection]
        NoSecrets[No Secrets Logged]
        Anonymize[Anonymize PII]
        Encrypt[Encrypt Logs]
    end

    AuthSuccess --> Logger
    AuthFail --> Logger
    PermChange --> Logger
    DataAccess --> Logger
    Error --> Logger

    Logger --> Filter
    Filter --> Format
    Format --> Timestamp
    Timestamp --> Local

    Local --> Rotate
    Logger --> NoSecrets
    Logger --> Anonymize
    Logger --> Encrypt
```

---

## Threat Model

```mermaid
flowchart TB
    subgraph Threats[Security Threats]
        T1[Man-in-the-Middle]
        T2[Device Theft]
        T3[Credential Theft]
        T4[Data Leakage]
        T5[API Abuse]
    end

    subgraph Mitigations[Mitigations]
        M1[TLS 1.3 + Pinning]
        M2[Biometric + Encryption]
        M3[Keychain + Secure Enclave]
        M4[AES-256-GCM + Access Control]
        M5[Rate Limiting + Signing]
    end

    subgraph Residual[Residual Risks]
        R1[Jailbroken Devices]
        R2[Social Engineering]
        R3[Zero-day Exploits]
    end

    T1 --> M1
    T2 --> M2
    T3 --> M3
    T4 --> M4
    T5 --> M5

    M1 -.-> R1
    M2 -.-> R2
    M3 -.-> R3
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
