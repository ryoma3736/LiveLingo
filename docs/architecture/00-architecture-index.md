# LiveLingo - Architecture Documentation Index

## Overview

This document catalogs all architecture diagrams for the LiveLingo application.
Total: 8 architecture diagrams across 8 categories.

---

## Architecture Diagram Categories

| Category | Diagram | Description |
|----------|---------|-------------|
| 01. System Overview | C4 Context Diagram | High-level system context and external actors |
| 02. Application Layers | Clean Architecture | MVVM + Clean Architecture layer structure |
| 03. Component Architecture | Component Diagram | All major components and dependencies |
| 04. Data Flow | Flow Diagram | End-to-end data transformation pipeline |
| 05. Network/API Layer | Integration Diagram | External API integrations and protocols |
| 06. Security Architecture | Security Layers | Authentication, encryption, permissions |
| 07. Audio Pipeline | Pipeline Diagram | STT -> Translation -> TTS processing |
| 08. State Management | State Diagram | Application states and transitions |

---

## Quick Reference

### Technology Stack

| Layer | Technology |
|-------|------------|
| UI Framework | SwiftUI |
| Reactive | Combine |
| Persistence | SwiftData |
| Speech Recognition | SFSpeechRecognizer, WhisperKit |
| Translation | Apple Translation, OpenAI, Anthropic |
| Text-to-Speech | AVSpeechSynthesizer, CoeFont API |
| Audio Session | AVAudioSession |
| Authentication | Sign in with Apple, Face ID/Touch ID |
| Security | Keychain, AES-256-GCM, TLS 1.3 |

### Supported Languages (8)

- Japanese (ja-JP)
- English US (en-US)
- English UK (en-GB)
- Chinese Simplified (zh-CN)
- Chinese Traditional (zh-TW)
- Korean (ko-KR)
- Vietnamese (vi-VN)
- Portuguese Brazil (pt-BR)

---

## Architecture Files

- `01-system-overview.md` - C4 Context and Container diagrams
- `02-application-layers.md` - MVVM + Clean Architecture structure
- `03-component-architecture.md` - Component relationships and dependencies
- `04-data-flow.md` - Data transformation and pipeline flow
- `05-network-api.md` - External API integration architecture
- `06-security-architecture.md` - Security controls and layers
- `07-audio-pipeline.md` - Real-time audio processing pipeline
- `08-state-management.md` - Application and component state machines

---

## Design Principles

### 1. Clean Architecture

```
Presentation Layer (SwiftUI Views)
       |
       v
Domain Layer (Use Cases, Entities)
       |
       v
Data Layer (Repositories, APIs, Storage)
```

### 2. MVVM Pattern

```
View <--> ViewModel <--> Model
  |           |           |
SwiftUI    Combine    SwiftData
```

### 3. Dependency Injection

All managers and services are injected via `DependencyContainer`.

### 4. Protocol-Oriented Programming

Interfaces defined as protocols for testability and flexibility.

---

## Key Performance Indicators (KPIs)

| Metric | Target |
|--------|--------|
| End-to-end Latency | < 1 second |
| Memory Usage (Active) | < 200MB |
| Memory Usage (Idle) | < 100MB |
| CPU Usage (Active) | < 60% |
| Test Coverage | > 80% |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2024-12-24 | Initial creation | AI Agent |
