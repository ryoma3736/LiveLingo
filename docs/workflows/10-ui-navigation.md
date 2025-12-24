# LiveLingo - UI Navigation Workflows

## WF-NAV-001: Splash to Home

Initial navigation after app launch.

```mermaid
sequenceDiagram
    participant System as iOS
    participant Splash as SplashView
    participant VM as SplashViewModel
    participant Auth as AuthManager
    participant Perm as PermissionManager
    participant Nav as NavigationController

    System->>Splash: present view

    Splash->>VM: onAppear()
    VM->>VM: startAnimation()
    Note over Splash: Logo animation 1.5s

    par Parallel Checks
        VM->>Auth: checkAuthenticationState()
        Auth-->>VM: isAuthenticated
        and
        VM->>Perm: checkAllPermissions()
        Perm-->>VM: permissionStatus
    end

    VM->>VM: wait(minimumDuration: 2s)

    alt First Launch
        VM->>Nav: navigate(.onboarding)
    else Permissions Missing
        VM->>Nav: navigate(.permissionRequest)
    else Not Authenticated
        VM->>Nav: navigate(.signIn)
    else Ready
        VM->>Nav: navigate(.home)
    end

    Nav->>Nav: transition(animation: .fade)
```

---

## WF-NAV-002: Onboarding Flow

First-time user setup wizard.

```mermaid
sequenceDiagram
    participant User
    participant OB as OnboardingView
    participant Page as PageController
    participant Perm as PermissionManager
    participant Lang as LanguageManager
    participant Store as UserDefaults

    OB->>Page: currentPage = 0

    loop Pages
        Page->>User: Display Current Page

        alt Page 0: Welcome
            Note over User: App introduction
            User->>Page: Tap Continue
            Page->>Page: currentPage = 1
        else Page 1: Features
            Note over User: Feature highlights
            User->>Page: Swipe/Continue
            Page->>Page: currentPage = 2
        else Page 2: Microphone Permission
            User->>OB: Tap "Allow Microphone"
            OB->>Perm: requestMicrophonePermission()
            Perm-->>OB: granted/denied
            Page->>Page: currentPage = 3
        else Page 3: Speech Recognition Permission
            User->>OB: Tap "Allow Speech Recognition"
            OB->>Perm: requestSpeechRecognitionPermission()
            Perm-->>OB: authorized/denied
            Page->>Page: currentPage = 4
        else Page 4: Language Selection
            User->>Lang: selectLanguagePair(ja, en)
            User->>Lang: selectAppLanguage(ja/en/zh)
            Page->>Page: currentPage = 5
        else Page 5: Ready
            Note over User: "You're all set!"
            User->>OB: Tap "Get Started"
        end
    end

    OB->>Store: set(true, forKey: "onboarding_complete")
    OB->>OB: navigateToHome()
```

---

## WF-NAV-003: Start Interpretation

Home to Interpretation screen transition.

```mermaid
sequenceDiagram
    participant User
    participant Home as HomeView
    participant VM as HomeViewModel
    participant Perm as PermissionManager
    participant Audio as AudioSessionManager
    participant Nav as NavigationPath
    participant Interp as InterpretationView

    User->>Home: Tap Start Button

    Home->>VM: startInterpretation()

    VM->>Perm: verifyPermissions()
    Perm-->>VM: allGranted

    alt Permissions OK
        VM->>Audio: prepareSession()
        Audio-->>VM: ready

        VM->>Nav: append(.interpretation(source, target))

        Nav->>Interp: present(animated: true)
        Interp->>Interp: initializeComponents()
        Interp->>Interp: startListening()
    else Permissions Missing
        VM->>Home: showPermissionAlert()
        Home->>User: Display "Permission Required"
        User->>Home: Tap "Open Settings"
        Home->>Home: openAppSettings()
    end
```

---

## WF-NAV-004: End Interpretation

Interpretation completion and result handling.

```mermaid
sequenceDiagram
    participant User
    participant Interp as InterpretationView
    participant VM as InterpretationViewModel
    participant Audio as AudioSessionManager
    participant Data as ConversationRepository
    participant Nav as NavigationPath
    participant Summary as SummaryView

    User->>Interp: Tap Stop Button

    Interp->>VM: stopInterpretation()

    VM->>VM: finalizingState = true
    VM->>Audio: stopRecording()
    VM->>VM: processRemainingAudio()

    VM->>Data: saveConversation()
    Data-->>VM: conversationID

    VM->>VM: generateSummary()
    Note over VM: Calculate duration,<br/>word count, segments

    VM-->>Interp: interpretationEnded

    Interp->>User: Show End Confirmation

    alt View Summary
        User->>Interp: Tap "View Summary"
        Interp->>Nav: append(.summary(conversationID))
        Nav->>Summary: present()
    else Return Home
        User->>Interp: Tap "Done"
        Interp->>Nav: removeLast()
        Nav->>Nav: pop to home
    end
```

---

## WF-NAV-005: Settings Navigation

Access settings and sub-screens.

```mermaid
sequenceDiagram
    participant User
    participant Home as HomeView
    participant Nav as NavigationPath
    participant Settings as SettingsView
    participant SubView as SubSettingsView

    User->>Home: Tap Settings Icon

    Home->>Nav: append(.settings)
    Nav->>Settings: present()

    Settings->>User: Display Settings Menu
    Note over Settings: Voice Settings<br/>Language Settings<br/>Privacy<br/>About

    alt Voice Settings
        User->>Settings: Tap "Voice Settings"
        Settings->>Nav: append(.voiceSettings)
        Nav->>SubView: present(VoiceSettingsView)

        User->>SubView: Configure voices
        SubView->>SubView: savePreferences()

        User->>SubView: Tap Back
        SubView->>Nav: removeLast()
    else Language Settings
        User->>Settings: Tap "Language Settings"
        Settings->>Nav: append(.languageSettings)
        Nav->>SubView: present(LanguageSettingsView)
    else Privacy
        User->>Settings: Tap "Privacy"
        Settings->>Nav: append(.privacy)
        Nav->>SubView: present(PrivacySettingsView)
    end

    User->>Settings: Tap Back
    Settings->>Nav: removeLast()
    Nav->>Home: pop to home
```

---

## WF-NAV-006: History Navigation

View and manage past conversations.

```mermaid
sequenceDiagram
    participant User
    participant Home as HomeView
    participant Nav as NavigationPath
    participant History as HistoryView
    participant VM as HistoryViewModel
    participant Detail as ConversationDetailView
    participant Search as SearchBar

    User->>Home: Tap History Icon

    Home->>Nav: append(.history)
    Nav->>History: present()

    History->>VM: loadConversations()
    VM->>VM: fetch from SwiftData
    VM-->>History: [Conversation]

    History->>History: groupByDate()
    History->>User: Display Conversation List

    alt View Conversation
        User->>History: Tap Conversation
        History->>Nav: append(.conversationDetail(id))
        Nav->>Detail: present()
        Detail->>User: Show Transcripts
    else Search
        User->>Search: Enter Query
        Search->>VM: search(query)
        VM->>VM: performSearch()
        VM-->>History: filteredResults
    else Delete
        User->>History: Swipe to Delete
        History->>VM: deleteConversation(id)
        VM->>VM: confirmDeletion()
        VM->>VM: delete from SwiftData
        History->>History: removeFromList()
    else Export
        User->>Detail: Tap Share
        Detail->>Detail: showExportOptions()
        User->>Detail: Select Format (JSON/CSV/TXT)
        Detail->>Detail: exportConversation()
        Detail->>User: Show Share Sheet
    end
```

---

## WF-NAV-007: Dictionary Management

Custom glossary editing.

```mermaid
sequenceDiagram
    participant User
    participant Home as HomeView
    participant Nav as NavigationPath
    participant Dict as DictionaryView
    participant VM as DictionaryViewModel
    participant Editor as EntryEditorView
    participant Data as GlossaryRepository

    User->>Home: Tap Dictionary Icon

    Home->>Nav: append(.dictionary)
    Nav->>Dict: present()

    Dict->>VM: loadGlossaries()
    VM->>Data: fetchAll()
    Data-->>VM: [Glossary]
    VM-->>Dict: glossaries

    Dict->>User: Display Glossary List

    alt Create New Glossary
        User->>Dict: Tap "+"
        Dict->>Nav: append(.createGlossary)
        Nav->>Editor: present(mode: .create)

        User->>Editor: Enter Name, Languages
        User->>Editor: Tap Save
        Editor->>VM: createGlossary(name, source, target)
        VM->>Data: save(glossary)
        Editor->>Nav: removeLast()
    else Edit Entry
        User->>Dict: Select Glossary
        Dict->>Nav: append(.glossaryDetail(id))

        User->>Dict: Tap Entry
        Dict->>Nav: append(.editEntry(id))
        Nav->>Editor: present(mode: .edit, entry)

        User->>Editor: Modify source/target text
        User->>Editor: Tap Save
        Editor->>VM: updateEntry(entry)
        Editor->>Nav: removeLast()
    else Delete Entry
        User->>Dict: Swipe Entry
        Dict->>VM: deleteEntry(id)
        Dict->>Dict: removeFromList()
    else Toggle Active
        User->>Dict: Toggle Switch
        Dict->>VM: setActive(glossaryID, isActive)
        Note over VM: Active glossaries used<br/>during translation
    end
```

---

## Navigation State Diagram

```mermaid
stateDiagram-v2
    [*] --> Splash

    Splash --> Onboarding: first launch
    Splash --> Home: returning user

    Onboarding --> Home: complete

    Home --> Interpretation: start
    Home --> Settings: tap settings
    Home --> History: tap history
    Home --> Dictionary: tap dictionary

    Interpretation --> Home: stop
    Interpretation --> Summary: view summary

    Summary --> Home: done

    Settings --> VoiceSettings: voice
    Settings --> LanguageSettings: language
    Settings --> PrivacySettings: privacy
    Settings --> Home: back

    VoiceSettings --> Settings: back
    LanguageSettings --> Settings: back
    PrivacySettings --> Settings: back

    History --> ConversationDetail: select
    History --> Home: back

    ConversationDetail --> History: back

    Dictionary --> GlossaryDetail: select
    Dictionary --> EntryEditor: add/edit
    Dictionary --> Home: back

    GlossaryDetail --> Dictionary: back
    EntryEditor --> GlossaryDetail: save/cancel
```

---

## Deep Link Handling

```mermaid
sequenceDiagram
    participant System as iOS
    participant App as AppDelegate
    participant Router as DeepLinkRouter
    participant Nav as NavigationController

    System->>App: openURL(livelingo://conversation/123)

    App->>Router: handle(url)
    Router->>Router: parse(url)
    Note over Router: scheme: livelingo<br/>path: /conversation/123

    alt Valid Deep Link
        Router->>Router: extractDestination()
        Router->>Nav: navigate(to: .conversationDetail(123))

        Nav->>Nav: buildNavigationStack()
        Note over Nav: Home -> History -> Detail
        Nav->>Nav: presentStack()
    else Invalid Deep Link
        Router->>Router: logInvalidLink()
        Router->>Nav: navigate(to: .home)
    end
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
