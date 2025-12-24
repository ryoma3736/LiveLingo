# LiveLingo - Workflow Index

## Overview

This document catalogs all identified workflows in the LiveLingo application.
Total: 50+ workflows across 14 categories.

---

## Category Index

| Category | Workflows | Priority |
|----------|-----------|----------|
| 01. Core Interpretation Pipeline | 5 | P0 |
| 02. App Lifecycle | 6 | P0 |
| 03. Speech Recognition (STT) | 8 | P0 |
| 04. Translation | 6 | P0 |
| 05. Text-to-Speech (TTS) | 5 | P0 |
| 06. Audio Session Management | 6 | P0 |
| 07. API Communication | 5 | P1 |
| 08. User Authentication | 4 | P1 |
| 09. Language Management | 5 | P1 |
| 10. UI Navigation | 7 | P1 |
| 11. Data Persistence | 6 | P2 |
| 12. Error Handling | 5 | P1 |
| 13. Performance Optimization | 4 | P2 |
| 14. Security & Privacy | 4 | P1 |

---

## 01. Core Interpretation Pipeline

| ID | Workflow | Description |
|----|----------|-------------|
| WF-CORE-001 | Main Interpretation Loop | Complete STT -> Translation -> TTS pipeline |
| WF-CORE-002 | Streaming Interpretation | Real-time streaming with Wait-k strategy |
| WF-CORE-003 | Dual Speaker Mode | Two-way interpretation for conversations |
| WF-CORE-004 | Single Speaker Mode | One-way interpretation |
| WF-CORE-005 | Pause Detection & Segment Processing | Automatic segment splitting |

## 02. App Lifecycle

| ID | Workflow | Description |
|----|----------|-------------|
| WF-LIFE-001 | Cold Start | App launch from terminated state |
| WF-LIFE-002 | Warm Start | App resume from background |
| WF-LIFE-003 | First Launch (Onboarding) | Initial setup and permissions |
| WF-LIFE-004 | Background Transition | App enters background during interpretation |
| WF-LIFE-005 | Foreground Transition | App returns to foreground |
| WF-LIFE-006 | App Termination | Graceful shutdown with data persistence |

## 03. Speech Recognition (STT)

| ID | Workflow | Description |
|----|----------|-------------|
| WF-STT-001 | Initialize SFSpeechRecognizer | Setup and permission check |
| WF-STT-002 | Real-time Recognition | Continuous speech to text |
| WF-STT-003 | Partial Result Processing | Interim results handling |
| WF-STT-004 | Final Result Processing | Confirmed transcription handling |
| WF-STT-005 | Pause Detection | Silence-based segment splitting |
| WF-STT-006 | Speaker Diarization | Dual speaker identification |
| WF-STT-007 | WhisperKit Fallback | Offline recognition fallback |
| WF-STT-008 | Language Auto-Detection | Automatic language identification |

## 04. Translation

| ID | Workflow | Description |
|----|----------|-------------|
| WF-TRN-001 | Apple Translation Framework | On-device translation |
| WF-TRN-002 | Cloud LLM Translation (OpenAI) | GPT-based translation |
| WF-TRN-003 | Cloud LLM Translation (Anthropic) | Claude-based translation |
| WF-TRN-004 | Wait-k Streaming | Low-latency streaming translation |
| WF-TRN-005 | Context-aware Translation | Multi-turn conversation context |
| WF-TRN-006 | Glossary Application | Custom dictionary integration |

## 05. Text-to-Speech (TTS)

| ID | Workflow | Description |
|----|----------|-------------|
| WF-TTS-001 | AVSpeechSynthesizer | System voice synthesis |
| WF-TTS-002 | CoeFont API Synthesis | AI voice synthesis |
| WF-TTS-003 | Personal Voice (iOS 17+) | User's personal voice |
| WF-TTS-004 | Streaming Audio Playback | Pre-buffered audio queue |
| WF-TTS-005 | Voice Selection | Choose and configure voices |

## 06. Audio Session Management

| ID | Workflow | Description |
|----|----------|-------------|
| WF-AUD-001 | Configure Audio Session | PlayAndRecord setup |
| WF-AUD-002 | Handle Phone Call Interruption | Pause/resume on call |
| WF-AUD-003 | Handle Siri Interruption | Pause/resume for Siri |
| WF-AUD-004 | Handle Route Change | Bluetooth connect/disconnect |
| WF-AUD-005 | Handle Media Server Reset | System audio recovery |
| WF-AUD-006 | Device Selection | Input/output device change |

## 07. API Communication

| ID | Workflow | Description |
|----|----------|-------------|
| WF-API-001 | CoeFont HMAC-SHA256 Auth | Signed API request |
| WF-API-002 | Retry with Exponential Backoff | Failed request retry |
| WF-API-003 | Rate Limit Handling | Request throttling |
| WF-API-004 | Offline Detection | Network state monitoring |
| WF-API-005 | Response Caching | Translation cache management |

## 08. User Authentication

| ID | Workflow | Description |
|----|----------|-------------|
| WF-AUTH-001 | Sign in with Apple | OAuth-style authentication |
| WF-AUTH-002 | Biometric Authentication | Face ID / Touch ID |
| WF-AUTH-003 | Session Validation | Check authentication state |
| WF-AUTH-004 | Sign Out | Clear session and credentials |

## 09. Language Management

| ID | Workflow | Description |
|----|----------|-------------|
| WF-LNG-001 | Language Pair Selection | Source/target language setup |
| WF-LNG-002 | Language Swap | Quick switch source/target |
| WF-LNG-003 | Language Pack Download | Offline model installation |
| WF-LNG-004 | App UI Language Switch | Change UI language (ja/en/zh) |
| WF-LNG-005 | Language Preference Persistence | Save user preferences |

## 10. UI Navigation

| ID | Workflow | Description |
|----|----------|-------------|
| WF-NAV-001 | Splash to Home | Initial navigation |
| WF-NAV-002 | Onboarding Flow | First-time user setup |
| WF-NAV-003 | Start Interpretation | Home -> Interpretation screen |
| WF-NAV-004 | End Interpretation | Interpretation -> Results |
| WF-NAV-005 | Settings Navigation | Access settings screens |
| WF-NAV-006 | History Navigation | View past conversations |
| WF-NAV-007 | Dictionary Management | Custom glossary editing |

## 11. Data Persistence

| ID | Workflow | Description |
|----|----------|-------------|
| WF-DATA-001 | Save Conversation | Persist to SwiftData |
| WF-DATA-002 | Load Conversation History | Fetch saved conversations |
| WF-DATA-003 | Search Conversations | Full-text search |
| WF-DATA-004 | Export Conversation | JSON/CSV/TXT export |
| WF-DATA-005 | Delete Conversation | Remove from storage |
| WF-DATA-006 | iCloud Sync | Cross-device synchronization |

## 12. Error Handling

| ID | Workflow | Description |
|----|----------|-------------|
| WF-ERR-001 | Network Error Recovery | Offline/timeout handling |
| WF-ERR-002 | STT Error Recovery | Recognition failure handling |
| WF-ERR-003 | API Error Display | User-friendly error messages |
| WF-ERR-004 | Permission Denied Handling | Guide to settings |
| WF-ERR-005 | Graceful Degradation | Fallback to alternatives |

## 13. Performance Optimization

| ID | Workflow | Description |
|----|----------|-------------|
| WF-PERF-001 | Memory Pressure Response | Cache eviction |
| WF-PERF-002 | Power Mode Switching | Battery-based optimization |
| WF-PERF-003 | Audio Buffer Pooling | Object reuse |
| WF-PERF-004 | API Latency Monitoring | Performance metrics |

## 14. Security & Privacy

| ID | Workflow | Description |
|----|----------|-------------|
| WF-SEC-001 | Keychain Access | Secure credential storage |
| WF-SEC-002 | Data Encryption | AES-256-GCM encryption |
| WF-SEC-003 | Permission Request | Microphone/Speech permission |
| WF-SEC-004 | Data Deletion | Privacy-compliant data removal |

---

## Sequence Diagram Files

Each workflow category has a dedicated sequence diagram file:

- `01-core-interpretation.md`
- `02-app-lifecycle.md`
- `03-stt-workflows.md`
- `04-translation-workflows.md`
- `05-tts-workflows.md`
- `06-audio-session.md`
- `07-api-communication.md`
- `08-authentication.md`
- `09-language-management.md`
- `10-ui-navigation.md`
- `11-data-persistence.md`
- `12-error-handling.md`
- `13-performance.md`
- `14-security-privacy.md`

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
