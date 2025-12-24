# LiveLingo - Authentication Workflows

## WF-AUTH-001: Sign in with Apple

OAuth-style authentication using Apple ID.

```mermaid
sequenceDiagram
    participant User
    participant UI as SignInView
    participant ASM as AppleSignInManager
    participant Provider as ASAuthorizationAppleIDProvider
    participant Controller as ASAuthorizationController
    participant Keychain as KeychainManager
    participant Backend as (Optional) Backend

    User->>UI: Tap "Sign in with Apple"
    UI->>ASM: signIn()

    ASM->>Provider: createRequest()
    Provider-->>ASM: request
    ASM->>ASM: request.requestedScopes = [.email, .fullName]

    ASM->>Controller: ASAuthorizationController(requests: [request])
    ASM->>Controller: delegate = self
    ASM->>Controller: presentationContextProvider = self

    Controller->>Controller: performRequests()

    Controller->>User: Present Apple Sign In Sheet

    alt User Authorizes
        User->>Controller: Approve
        Controller->>ASM: didCompleteWithAuthorization(authorization)

        ASM->>ASM: extract credential
        Note over ASM: userID, email, fullName,<br/>identityToken, authorizationCode

        ASM->>Keychain: save(userID, forKey: "appleUserID")

        opt Backend Integration
            ASM->>Backend: POST /auth/apple {identityToken}
            Backend-->>ASM: sessionToken
            ASM->>Keychain: save(sessionToken)
        end

        ASM->>ASM: isAuthenticated = true
        ASM-->>UI: authentication success
        UI->>UI: navigateToHome()
    else User Cancels
        User->>Controller: Cancel
        Controller->>ASM: didCompleteWithError(error)
        ASM-->>UI: authentication cancelled
    else Error
        Controller->>ASM: didCompleteWithError(error)
        ASM-->>UI: show error
    end
```

---

## WF-AUTH-002: Biometric Authentication

Face ID / Touch ID authentication.

```mermaid
sequenceDiagram
    participant User
    participant UI as BiometricPromptView
    participant BAM as BiometricAuthManager
    participant Context as LAContext
    participant Keychain as KeychainManager

    User->>UI: Attempt Secure Action
    UI->>BAM: authenticate(reason: "Unlock LiveLingo")

    BAM->>Context: LAContext()
    BAM->>Context: canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics)

    alt Biometric Available
        Context-->>BAM: true, biometryType: .faceID

        BAM->>Context: evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,<br/>localizedReason: reason)

        Context->>User: Present Face ID / Touch ID

        alt Authentication Success
            User->>Context: Biometric Match
            Context-->>BAM: success: true

            BAM->>Keychain: unlockSecureData()
            BAM-->>UI: authenticated

            UI->>UI: proceedWithSecureAction()
        else Authentication Failed
            User->>Context: Biometric Mismatch
            Context-->>BAM: error: .authenticationFailed

            BAM-->>UI: showError("Authentication failed")

            alt Lockout
                BAM->>UI: offerPasscodeEntry()
            else Retry Available
                BAM->>UI: offerRetry()
            end
        else User Cancelled
            User->>Context: Cancel
            Context-->>BAM: error: .userCancel
            BAM-->>UI: cancelled
        end
    else Biometric Not Available
        Context-->>BAM: false
        BAM->>BAM: checkBiometryType()

        alt Not Enrolled
            BAM-->>UI: showEnrollmentPrompt()
        else Not Available (device)
            BAM-->>UI: fallbackToPasscode()
        else Lockout
            BAM-->>UI: showLockoutMessage()
        end
    end
```

---

## WF-AUTH-003: Session Validation

Check authentication state on app launch.

```mermaid
sequenceDiagram
    participant App as Application
    participant ASM as AppleSignInManager
    participant Provider as ASAuthorizationAppleIDProvider
    participant Keychain as KeychainManager
    participant UI as RootNavigationController

    App->>ASM: checkAuthenticationState()

    ASM->>Keychain: getString(forKey: "appleUserID")

    alt UserID Exists
        Keychain-->>ASM: storedUserID

        ASM->>Provider: getCredentialState(forUserID: storedUserID)
        Provider-->>ASM: credentialState

        alt Authorized
            ASM->>ASM: isAuthenticated = true
            ASM-->>UI: showHome()
        else Revoked
            Note over ASM: User revoked access in<br/>Settings > Apple ID > Password & Security
            ASM->>Keychain: delete(forKey: "appleUserID")
            ASM->>ASM: isAuthenticated = false
            ASM-->>UI: showSignIn()
        else Not Found
            ASM->>Keychain: delete(forKey: "appleUserID")
            ASM->>ASM: isAuthenticated = false
            ASM-->>UI: showSignIn()
        else Transferred
            Note over ASM: Account transferred to different device
            ASM->>ASM: handleAccountTransfer()
        end
    else No UserID
        Keychain-->>ASM: nil
        ASM->>ASM: isAuthenticated = false
        ASM-->>UI: showSignIn() or showOnboarding()
    end
```

---

## WF-AUTH-004: Sign Out

Clear session and credentials.

```mermaid
sequenceDiagram
    participant User
    participant UI as SettingsView
    participant ASM as AppleSignInManager
    participant Keychain as KeychainManager
    participant Data as DataManager
    participant Nav as NavigationController

    User->>UI: Tap "Sign Out"

    UI->>UI: showConfirmationAlert()
    User->>UI: Confirm

    UI->>ASM: signOut()

    ASM->>Keychain: delete(forKey: "appleUserID")
    ASM->>Keychain: delete(forKey: "sessionToken")

    opt Clear Local Data
        ASM->>Data: clearUserData()
        Data->>Data: deleteConversations()
        Data->>Data: clearCache()
    end

    ASM->>ASM: isAuthenticated = false
    ASM->>ASM: userID = nil
    ASM->>ASM: email = nil

    ASM-->>Nav: notifySignOut()
    Nav->>Nav: resetToSignIn()
    Nav->>UI: dismiss all modals
    Nav->>UI: present SignInView
```

---

## Secure Data Access with Biometrics

```mermaid
sequenceDiagram
    participant User
    participant App as Application
    participant BAM as BiometricAuthManager
    participant Keychain as KeychainManager
    participant Crypto as EncryptionManager

    User->>App: Access Secure Feature<br/>(API Keys, History Export)

    App->>BAM: authenticate(reason: "Access secure data")
    BAM->>BAM: evaluatePolicy()

    alt Authenticated
        BAM-->>App: success

        App->>Keychain: getData(forKey: "encryptionKey",<br/>accessControl: .biometryCurrentSet)

        Keychain->>Keychain: verify biometric state
        Keychain-->>App: encryptionKeyData

        App->>Crypto: decryptSecureData(using: key)
        Crypto-->>App: decryptedData

        App->>User: Show Secure Content
    else Not Authenticated
        BAM-->>App: failed

        App->>User: Show Access Denied
    end
```

---

## Authentication State Diagram

```mermaid
stateDiagram-v2
    [*] --> Unknown

    Unknown --> Checking: app launch
    Checking --> SignedOut: no credentials
    Checking --> Validating: has credentials

    Validating --> SignedIn: credentials valid
    Validating --> Revoked: credentials revoked
    Validating --> SignedOut: credentials invalid

    Revoked --> SignedOut: clear data

    SignedOut --> SigningIn: user taps sign in
    SigningIn --> SignedIn: success
    SigningIn --> SignedOut: cancelled/failed

    SignedIn --> BiometricChallenge: access secure feature
    BiometricChallenge --> SignedIn: success
    BiometricChallenge --> SignedIn: failed (stay signed in)

    SignedIn --> SigningOut: user signs out
    SigningOut --> SignedOut: complete

    SignedIn --> SessionExpired: token expired
    SessionExpired --> SigningIn: re-authenticate
```

---

## Keychain Access Control

```mermaid
flowchart TD
    subgraph KeychainItems[Keychain Items]
        A[Apple User ID]
        B[Session Token]
        C[Encryption Key]
        D[API Keys]
    end

    subgraph AccessControl[Access Control]
        AC1[kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        AC2[kSecAttrAccessControlBiometryCurrentSet]
    end

    A --> AC1
    B --> AC1
    C --> AC2
    D --> AC2

    subgraph Protection
        P1[Available when device unlocked]
        P2[Requires biometric authentication]
        P3[Invalidated if biometrics change]
    end

    AC1 --> P1
    AC2 --> P2
    AC2 --> P3
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
