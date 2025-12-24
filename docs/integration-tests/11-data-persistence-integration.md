# IT-DATA: Data Persistence Integration Tests

## Overview

This document defines integration tests for data persistence based on workflows WF-DATA-001 through WF-DATA-006. These tests verify SwiftData operations, search, export, and iCloud synchronization.

**Priority**: P1-High
**Total Test Cases**: 42
**Estimated Execution Time**: 15 minutes

---

## Test Environment

### Required Components
- `DataManager`
- `ModelContainer` (SwiftData)
- `CloudKitManager`
- `ExportManager`
- `SearchManager`

### Mock Dependencies
- `MockModelContainer`
- `MockCloudKit`

### Data Models
- `Conversation`
- `Utterance`
- `TranslationPair`
- `UserSettings`

---

## WF-DATA-001: Save Conversation

### Test Case IT-DATA-001-01: Save Complete Conversation

**Objective**: Verify conversation saved to SwiftData.

**Preconditions**:
- Conversation in memory
- At least 5 utterances

**Test Steps**:
1. Complete interpretation session
2. Tap save
3. Verify persistence

**Expected Results**:
- [ ] Conversation saved
- [ ] All utterances included
- [ ] Timestamp recorded
- [ ] Retrievable after restart

```swift
func testSaveConversation() async throws {
    let dataManager = DataManager()

    let conversation = Conversation(
        id: UUID(),
        sourceLanguage: .japanese,
        targetLanguage: .english,
        createdAt: Date(),
        utterances: [
            Utterance(speaker: .a, original: "こんにちは", translated: "Hello"),
            Utterance(speaker: .b, original: "Nice to meet you", translated: "はじめまして")
        ]
    )

    try await dataManager.save(conversation)

    let retrieved = try await dataManager.fetchConversation(id: conversation.id)
    XCTAssertNotNil(retrieved)
    XCTAssertEqual(retrieved?.utterances.count, 2)
}
```

---

### Test Case IT-DATA-001-02: Save with Large Transcript

**Objective**: Verify large conversations save correctly.

**Test Steps**:
1. Create conversation with 100+ utterances
2. Save
3. Verify complete save

**Expected Results**:
- [ ] All utterances saved
- [ ] No truncation
- [ ] Performance acceptable
- [ ] Memory managed

---

### Test Case IT-DATA-001-03: Save with Audio Reference

**Objective**: Verify audio file reference saved.

**Test Steps**:
1. Record audio during interpretation
2. Save conversation with audio
3. Verify audio reference

**Expected Results**:
- [ ] Audio file path saved
- [ ] File exists on disk
- [ ] Playback works
- [ ] Cleanup on delete

---

### Test Case IT-DATA-001-04: Auto-Save During Session

**Objective**: Verify auto-save protects against data loss.

**Test Steps**:
1. Start interpretation
2. Process 10 utterances
3. Kill app
4. Relaunch

**Expected Results**:
- [ ] Draft saved periodically
- [ ] Recovery possible
- [ ] Prompt to restore
- [ ] No data loss

---

### Test Case IT-DATA-001-05: Save Failure Handling

**Objective**: Verify graceful handling of save failure.

**Test Steps**:
1. Fill disk storage
2. Attempt save
3. Verify error handling

**Expected Results**:
- [ ] Error caught
- [ ] User notified
- [ ] Data retained in memory
- [ ] Retry available

---

### Test Case IT-DATA-001-06: Concurrent Save Operations

**Objective**: Verify concurrent saves don't conflict.

**Test Steps**:
1. Start two saves simultaneously
2. Verify both complete

**Expected Results**:
- [ ] Both saves succeed
- [ ] No data corruption
- [ ] Proper locking
- [ ] Consistent state

---

## WF-DATA-002: Load Conversation

### Test Case IT-DATA-002-01: Load Single Conversation

**Objective**: Verify conversation loads correctly.

**Test Steps**:
1. Have saved conversation
2. Request by ID
3. Verify loaded data

**Expected Results**:
- [ ] Correct conversation returned
- [ ] All fields populated
- [ ] Relationships loaded
- [ ] Quick response

```swift
func testLoadConversation() async throws {
    let dataManager = DataManager()

    // Pre-existing conversation
    let conversationId = UUID()
    try await dataManager.save(Conversation(id: conversationId, ...))

    let loaded = try await dataManager.fetchConversation(id: conversationId)

    XCTAssertNotNil(loaded)
    XCTAssertEqual(loaded?.id, conversationId)
    XCTAssertGreaterThan(loaded?.utterances.count ?? 0, 0)
}
```

---

### Test Case IT-DATA-002-02: Load Conversation List

**Objective**: Verify conversation list loads efficiently.

**Test Steps**:
1. Have 100 saved conversations
2. Request list
3. Verify performance

**Expected Results**:
- [ ] List loaded < 500ms
- [ ] Sorted by date
- [ ] Pagination works
- [ ] Metadata only (lazy load)

---

### Test Case IT-DATA-002-03: Load Non-Existent

**Objective**: Verify handling of missing conversation.

**Test Steps**:
1. Request non-existent ID
2. Verify response

**Expected Results**:
- [ ] nil returned (not error)
- [ ] Or specific error type
- [ ] App doesn't crash
- [ ] Logged for debugging

---

### Test Case IT-DATA-002-04: Lazy Loading Relationships

**Objective**: Verify relationships load lazily.

**Test Steps**:
1. Load conversation (no utterances accessed)
2. Verify utterances not fetched
3. Access utterances
4. Verify fetch happens

**Expected Results**:
- [ ] Initial load lightweight
- [ ] Relationships on-demand
- [ ] Performance optimal
- [ ] Memory efficient

---

## WF-DATA-003: Full-Text Search

### Test Case IT-DATA-003-01: Search by Keyword

**Objective**: Verify keyword search works.

**Test Steps**:
1. Have conversations with various content
2. Search for "こんにちは"
3. Verify matching results

**Expected Results**:
- [ ] Matching conversations returned
- [ ] Search in original and translated
- [ ] Relevant ranking
- [ ] Fast response

```swift
func testFullTextSearch() async throws {
    let searchManager = SearchManager()

    // Pre-populate data
    await setupTestConversations()

    let results = try await searchManager.search(query: "weather")

    XCTAssertGreaterThan(results.count, 0)
    XCTAssertTrue(results.first?.containsMatch(for: "weather") ?? false)
}
```

---

### Test Case IT-DATA-003-02: Search Performance

**Objective**: Verify search scales with data.

**Test Steps**:
1. Create 1000 conversations
2. Run search
3. Measure response time

**Expected Results**:
- [ ] Search < 1 second
- [ ] Indexed properly
- [ ] No UI freeze
- [ ] Results paginated

---

### Test Case IT-DATA-003-03: Search with Filters

**Objective**: Verify filtered search works.

**Test Steps**:
1. Search with date range filter
2. Search with language filter
3. Combine filters

**Expected Results**:
- [ ] Date filter works
- [ ] Language filter works
- [ ] Combined filters AND logic
- [ ] Empty results handled

---

### Test Case IT-DATA-003-04: Search Highlighting

**Objective**: Verify matches highlighted in results.

**Test Steps**:
1. Search for term
2. Check result display
3. Verify highlighting

**Expected Results**:
- [ ] Match term highlighted
- [ ] Context around match shown
- [ ] Multiple matches shown
- [ ] UI indicates relevance

---

### Test Case IT-DATA-003-05: Japanese Text Search

**Objective**: Verify Japanese text search works.

**Test Steps**:
1. Search for Japanese characters
2. Search for romaji
3. Verify results

**Expected Results**:
- [ ] Japanese search works
- [ ] Character encoding correct
- [ ] Partial matches found
- [ ] Kanji/hiragana both work

---

## WF-DATA-004: Export Conversation

### Test Case IT-DATA-004-01: Export as JSON

**Objective**: Verify JSON export format.

**Test Steps**:
1. Select conversation
2. Export as JSON
3. Verify file content

**Expected Results**:
- [ ] Valid JSON file
- [ ] All fields included
- [ ] Proper escaping
- [ ] Readable structure

```swift
func testExportJSON() async throws {
    let exportManager = ExportManager()
    let conversation = testConversation

    let jsonData = try await exportManager.export(conversation, format: .json)
    let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

    XCTAssertNotNil(json)
    XCTAssertNotNil(json?["utterances"])
    XCTAssertNotNil(json?["sourceLanguage"])
}
```

---

### Test Case IT-DATA-004-02: Export as CSV

**Objective**: Verify CSV export format.

**Test Steps**:
1. Select conversation
2. Export as CSV
3. Verify file content

**Expected Results**:
- [ ] Valid CSV file
- [ ] Headers included
- [ ] Proper escaping
- [ ] Opens in Excel

---

### Test Case IT-DATA-004-03: Export as TXT

**Objective**: Verify plain text export.

**Test Steps**:
1. Select conversation
2. Export as TXT
3. Verify readability

**Expected Results**:
- [ ] Human-readable format
- [ ] Speaker labels
- [ ] Timestamps (optional)
- [ ] Clean formatting

---

### Test Case IT-DATA-004-04: Export Multiple Conversations

**Objective**: Verify batch export works.

**Test Steps**:
1. Select 5 conversations
2. Export all
3. Verify output

**Expected Results**:
- [ ] All 5 exported
- [ ] ZIP or combined file
- [ ] Progress shown
- [ ] Large export handled

---

### Test Case IT-DATA-004-05: Share Export

**Objective**: Verify export shares correctly.

**Test Steps**:
1. Export conversation
2. Tap share
3. Verify share sheet

**Expected Results**:
- [ ] Share sheet presented
- [ ] File attachable
- [ ] Multiple destinations
- [ ] Sent successfully

---

## WF-DATA-005: Delete Conversation

### Test Case IT-DATA-005-01: Delete Single Conversation

**Objective**: Verify conversation deletion.

**Test Steps**:
1. Have saved conversation
2. Delete
3. Verify removal

**Expected Results**:
- [ ] Conversation removed
- [ ] Not in list
- [ ] Not searchable
- [ ] Related data cleaned

```swift
func testDeleteConversation() async throws {
    let dataManager = DataManager()

    let conversation = Conversation(id: UUID(), ...)
    try await dataManager.save(conversation)

    try await dataManager.delete(conversation)

    let retrieved = try await dataManager.fetchConversation(id: conversation.id)
    XCTAssertNil(retrieved)
}
```

---

### Test Case IT-DATA-005-02: Delete with Cascade

**Objective**: Verify related data deleted.

**Test Steps**:
1. Delete conversation
2. Verify utterances deleted
3. Verify audio files deleted

**Expected Results**:
- [ ] Utterances removed
- [ ] Audio files removed
- [ ] No orphaned data
- [ ] Disk space freed

---

### Test Case IT-DATA-005-03: Delete Confirmation

**Objective**: Verify delete requires confirmation.

**Test Steps**:
1. Tap delete
2. Verify confirmation dialog
3. Cancel
4. Confirm

**Expected Results**:
- [ ] Dialog shown
- [ ] Cancel preserves data
- [ ] Confirm deletes
- [ ] No accidental deletion

---

### Test Case IT-DATA-005-04: Bulk Delete

**Objective**: Verify multiple deletion.

**Test Steps**:
1. Select 10 conversations
2. Delete all
3. Verify removal

**Expected Results**:
- [ ] All 10 deleted
- [ ] Single confirmation
- [ ] Progress shown for large
- [ ] Atomic operation

---

### Test Case IT-DATA-005-05: Delete All Data

**Objective**: Verify clear all data function.

**Test Steps**:
1. "Delete All Data" in settings
2. Confirm
3. Verify complete wipe

**Expected Results**:
- [ ] All conversations deleted
- [ ] Settings reset (optional)
- [ ] Caches cleared
- [ ] Fresh state

---

## WF-DATA-006: iCloud Sync

### Test Case IT-DATA-006-01: Initial Sync

**Objective**: Verify initial iCloud sync.

**Preconditions**:
- iCloud signed in
- Sync enabled

**Test Steps**:
1. Enable sync on device A
2. Create conversation
3. Check device B

**Expected Results**:
- [ ] Sync triggered
- [ ] Data appears on device B
- [ ] Within reasonable time
- [ ] No duplicates

```swift
func testICloudSync() async throws {
    let cloudManager = CloudKitManager()

    // Save locally
    let conversation = Conversation(...)
    try await DataManager.shared.save(conversation)

    // Wait for sync
    try await Task.sleep(nanoseconds: 5_000_000_000)

    // Verify in CloudKit
    let cloudRecord = try await cloudManager.fetch(id: conversation.id)
    XCTAssertNotNil(cloudRecord)
}
```

---

### Test Case IT-DATA-006-02: Conflict Resolution

**Objective**: Verify sync conflict handling.

**Test Steps**:
1. Modify same conversation on two devices
2. Both sync
3. Verify resolution

**Expected Results**:
- [ ] Conflict detected
- [ ] Resolution strategy applied
- [ ] No data loss
- [ ] User may be prompted

---

### Test Case IT-DATA-006-03: Offline Changes Sync

**Objective**: Verify offline changes sync when online.

**Test Steps**:
1. Go offline
2. Create conversation
3. Go online
4. Verify sync

**Expected Results**:
- [ ] Changes queued offline
- [ ] Sync on reconnect
- [ ] Data consistent
- [ ] No user action needed

---

### Test Case IT-DATA-006-04: Sync Status Indicator

**Objective**: Verify sync status visible.

**Test Steps**:
1. Make change
2. Observe sync indicator
3. Wait for completion
4. Verify indicator

**Expected Results**:
- [ ] Pending sync shown
- [ ] Syncing animation
- [ ] Complete indicator
- [ ] Error indicator if failed

---

### Test Case IT-DATA-006-05: Disable Sync

**Objective**: Verify sync can be disabled.

**Test Steps**:
1. Disable iCloud sync
2. Create conversation
3. Verify local only

**Expected Results**:
- [ ] Sync stops
- [ ] New data local only
- [ ] Existing synced data remains
- [ ] Re-enable works

---

### Test Case IT-DATA-006-06: Large Data Sync

**Objective**: Verify large data sets sync.

**Test Steps**:
1. Create 100 conversations
2. Wait for sync
3. Verify on other device

**Expected Results**:
- [ ] All data syncs
- [ ] May take time
- [ ] Progress shown
- [ ] No failures

---

## Data Migration

### Test Case IT-DATA-MIG-01: Schema Migration

**Objective**: Verify schema migration works.

**Test Steps**:
1. Old version database
2. Update app
3. Launch
4. Verify migration

**Expected Results**:
- [ ] Migration detected
- [ ] Data preserved
- [ ] Schema updated
- [ ] No data loss

---

### Test Case IT-DATA-MIG-02: Migration Rollback

**Objective**: Verify rollback on migration failure.

**Test Steps**:
1. Simulate migration failure
2. Verify rollback

**Expected Results**:
- [ ] Failure detected
- [ ] Original data intact
- [ ] Error reported
- [ ] App usable

---

## Performance Tests

### Test Case IT-DATA-PERF-01: Large Dataset Performance

**Objective**: Verify performance with large data.

**Test Steps**:
1. 10,000 conversations
2. Measure list load
3. Measure search
4. Measure scroll

**Expected Results**:
- [ ] List loads < 2 seconds
- [ ] Search < 1 second
- [ ] Scrolling smooth
- [ ] Memory bounded

---

### Test Case IT-DATA-PERF-02: Database Size Growth

**Objective**: Verify database size manageable.

**Test Steps**:
1. Track database size over time
2. After 1000 conversations
3. Verify growth rate

**Expected Results**:
- [ ] Growth linear
- [ ] No bloat
- [ ] Cleanup works
- [ ] Size reasonable

---

## Test Data Fixtures

### Conversation Templates

| ID | Utterances | Duration | Languages |
|----|------------|----------|-----------|
| `short` | 5 | 1 min | ja-en |
| `medium` | 50 | 10 min | ja-en |
| `long` | 200 | 30 min | ja-en |
| `multilingual` | 30 | 5 min | ja-en-zh |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation with 42 test cases | AI Agent |
