# LiveLingo - Data Persistence Workflows

## WF-DATA-001: Save Conversation

Persist conversation to SwiftData.

```mermaid
sequenceDiagram
    participant VM as InterpretationViewModel
    participant Repo as ConversationRepository
    participant Context as ModelContext
    participant SwiftData as SwiftData
    participant iCloud as CloudKit (optional)

    VM->>VM: interpretationEnded()

    VM->>Repo: save(conversation)

    Repo->>Repo: conversation.updatedAt = Date()
    Repo->>Repo: conversation.generateTitle()

    Repo->>Context: insert(conversation)

    loop For each transcript
        Repo->>Context: transcript.conversation = conversation
    end

    Repo->>Context: save()

    alt Save Success
        Context->>SwiftData: persist to local store
        SwiftData-->>Context: saved

        alt iCloud Enabled
            SwiftData->>iCloud: sync changes
            iCloud-->>SwiftData: synced
        end

        Repo-->>VM: success(conversationID)
    else Save Failed
        Context-->>Repo: error
        Repo->>Repo: handleSaveError()
        Repo-->>VM: failure(error)
    end
```

---

## WF-DATA-002: Load Conversation History

Fetch saved conversations with filtering.

```mermaid
sequenceDiagram
    participant UI as HistoryView
    participant VM as HistoryViewModel
    participant Repo as ConversationRepository
    participant Context as ModelContext

    UI->>VM: onAppear()
    VM->>Repo: getRecent(limit: 50)

    Repo->>Repo: buildFetchDescriptor()
    Note over Repo: sortBy: updatedAt DESC<br/>fetchLimit: 50

    Repo->>Context: fetch(descriptor)
    Context-->>Repo: [Conversation]

    Repo-->>VM: conversations

    VM->>VM: groupByDate()
    Note over VM: Today, Yesterday,<br/>This Week, Older

    VM-->>UI: sections

    UI->>UI: display(sections)

    alt Load More (Pagination)
        UI->>VM: loadMore()
        VM->>Repo: getRecent(limit: 50, offset: 50)
        Repo->>Context: fetch with offset
        Context-->>Repo: moreConversations
        VM->>VM: appendToSections()
        VM-->>UI: updatedSections
    end
```

---

## WF-DATA-003: Search Conversations

Full-text search across transcripts.

```mermaid
sequenceDiagram
    participant User
    participant UI as SearchBar
    participant VM as HistoryViewModel
    participant Repo as ConversationRepository
    participant Context as ModelContext

    User->>UI: Enter "meeting"
    UI->>UI: debounce(300ms)

    UI->>VM: search(query: "meeting")

    VM->>VM: showLoadingIndicator()

    VM->>Repo: search(query: "meeting")

    Repo->>Repo: buildSearchPredicate()
    Note over Repo: #Predicate { conversation in<br/>  conversation.transcripts.contains {<br/>    $0.originalText.contains(query) ||<br/>    $0.translatedText.contains(query)<br/>  }<br/>}

    Repo->>Context: fetch(searchDescriptor)
    Context-->>Repo: matchingConversations

    Repo-->>VM: results

    VM->>VM: highlightMatches(query)
    VM->>VM: hideLoadingIndicator()

    VM-->>UI: searchResults

    UI->>UI: display(results, highlighting: "meeting")

    alt No Results
        UI->>User: Show "No results found"
    else Has Results
        User->>UI: Tap Result
        UI->>UI: navigate(to: conversationDetail)
    end
```

---

## WF-DATA-004: Export Conversation

Export to JSON/CSV/TXT formats.

```mermaid
sequenceDiagram
    participant User
    participant UI as ConversationDetailView
    participant VM as ExportViewModel
    participant Export as DataExportManager
    participant Share as UIActivityViewController

    User->>UI: Tap Share Button

    UI->>UI: showExportOptions()
    Note over UI: JSON, CSV, TXT

    User->>UI: Select CSV

    UI->>VM: exportConversation(format: .csv)

    VM->>Export: export(conversation, format: .csv)

    Export->>Export: buildCSVContent()
    Note over Export: Header: Speaker,Original,Translated,Timestamp

    loop For each transcript
        Export->>Export: formatRow(transcript)
        Export->>Export: escapeCSVCharacters()
        Export->>Export: appendRow()
    end

    Export->>Export: encodeToData(utf8)
    Export-->>VM: csvData

    VM->>VM: createTemporaryFile(data, .csv)
    VM-->>UI: fileURL

    UI->>Share: present(fileURL)
    Share->>User: Show Share Sheet

    alt AirDrop
        User->>Share: Select AirDrop
        Share->>Share: sendViaAirDrop()
    else Save to Files
        User->>Share: Select Files
        Share->>Share: saveToFiles()
    else Email
        User->>Share: Select Mail
        Share->>Share: attachToEmail()
    end
```

---

## WF-DATA-005: Delete Conversation

Remove conversation from storage.

```mermaid
sequenceDiagram
    participant User
    participant UI as HistoryView
    participant VM as HistoryViewModel
    participant Repo as ConversationRepository
    participant Context as ModelContext
    participant Cache as TranslationCache

    User->>UI: Swipe to Delete

    UI->>UI: showDeleteConfirmation()
    User->>UI: Confirm Delete

    UI->>VM: deleteConversation(id)

    VM->>Repo: get(by: id)
    Repo->>Context: fetch(predicate: id)
    Context-->>Repo: conversation

    Repo->>Repo: prepareForDeletion()

    par Cascade Delete
        Repo->>Context: delete(conversation)
        Note over Context: Cascades to transcripts<br/>via @Relationship deleteRule
        and
        Repo->>Cache: invalidateRelated(conversationID)
    end

    Repo->>Context: save()
    Context-->>Repo: deleted

    Repo-->>VM: success

    VM->>VM: removeFromList(id)
    VM-->>UI: conversationDeleted

    UI->>UI: animateRemoval()
```

---

## WF-DATA-006: iCloud Sync

Cross-device synchronization.

```mermaid
sequenceDiagram
    participant Device1 as Device A
    participant SwiftData1 as SwiftData A
    participant CloudKit as CloudKit
    participant SwiftData2 as SwiftData B
    participant Device2 as Device B

    Note over Device1: User creates conversation

    Device1->>SwiftData1: save(conversation)
    SwiftData1->>SwiftData1: persist locally

    SwiftData1->>CloudKit: sync changes
    Note over CloudKit: CKRecord created/updated

    CloudKit->>CloudKit: store in iCloud

    alt Device B Online
        CloudKit->>SwiftData2: push notification
        SwiftData2->>CloudKit: fetch changes

        CloudKit-->>SwiftData2: updated records

        SwiftData2->>SwiftData2: merge changes
        SwiftData2->>Device2: notify UI
        Device2->>Device2: refresh views
    else Device B Offline
        Note over SwiftData2: Changes queued

        SwiftData2->>SwiftData2: deviceComesOnline()
        SwiftData2->>CloudKit: fetch pending changes
        CloudKit-->>SwiftData2: all updates
        SwiftData2->>SwiftData2: merge()
    end
```

---

## Data Model Relationships

```mermaid
erDiagram
    Conversation ||--o{ TranscriptItem : contains
    Conversation {
        UUID id PK
        string title
        string sourceLanguageCode
        string targetLanguageCode
        date createdAt
        date updatedAt
        float duration
        bool isFavorite
    }

    TranscriptItem {
        UUID id PK
        int speakerID
        string originalText
        string translatedText
        date timestamp
        float duration
        float confidence
    }

    UserSettings ||--o| Conversation : uses
    UserSettings {
        UUID id PK
        string sourceLanguageCode
        string targetLanguageCode
        string appLanguageCode
        float speechRate
        float volume
        bool powerSavingMode
    }

    Glossary ||--o{ GlossaryEntry : contains
    Glossary {
        UUID id PK
        string name
        string sourceLanguageCode
        string targetLanguageCode
        bool isActive
    }

    GlossaryEntry {
        UUID id PK
        string sourceText
        string targetText
        bool caseSensitive
        string context
    }

    VoicePreference {
        UUID id PK
        string languageCode
        string voiceID
        string voiceType
        string displayName
    }
```

---

## Cache Management Flow

```mermaid
flowchart TD
    A[Translation Request] --> B{Check Memory Cache}
    B -->|Hit| C[Return Cached]
    B -->|Miss| D{Check Disk Cache}

    D -->|Hit| E[Load to Memory]
    E --> C

    D -->|Miss| F[Call Translation API]
    F --> G[Store in Memory Cache]
    G --> H[Store in Disk Cache]
    H --> I[Return Translation]

    J[Memory Pressure] --> K{Usage > 75%?}
    K -->|Yes| L[Evict LRU Entries]
    K -->|No| M[Continue]

    N[Cache Expiry Check] --> O{Entry > 1 hour?}
    O -->|Yes| P[Remove Entry]
    O -->|No| M

    Q[App Termination] --> R[Persist Important Caches]
    R --> S[Clear Temporary Caches]
```

---

## Migration Strategy

```mermaid
sequenceDiagram
    participant App as Application
    participant Container as ModelContainer
    participant Migration as MigrationPlan
    participant Schema as VersionedSchema

    App->>Container: initialize with migration plan

    Container->>Migration: getSchemasToMigrate()
    Migration->>Schema: currentVersion?

    alt Migration Needed
        Migration->>Migration: determineStages()
        Note over Migration: V1 -> V2: add new fields<br/>V2 -> V3: restructure

        loop For each stage
            Migration->>Migration: willMigrate(context)
            Migration->>Migration: performMigration()
            Migration->>Migration: didMigrate(context)
        end

        Migration-->>Container: migration complete
    else No Migration
        Container-->>App: ready
    end

    Container-->>App: ModelContext ready
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
