# Project: Gem (Personal Life OS & Antigravity Assistant)

## Architecture
Gem is a Flutter-based desktop application for Windows and Linux that uses Clean Architecture principles.
- **Presentation Layer**: Riverpod state providers, Glassmorphic UI views, custom charts, interactive node graphs for subagents, and chat interfaces.
- **Domain Layer**: Models for health metrics (steps, sleep, heart rate), CLI state, subagent process node structure, and interface definitions (repositories).
- **Data Layer**: Local cache repository, OAuth 2.0 desktop loopback implementation, `config.json` loader, process wrapper for running the `agy` CLI, and JSONL log parsing logic.

### Directory Structure
```
lib/
├── main.dart
├── core/                  # Theme, utils, config, constants
├── data/
│   ├── models/            # JSON serialization for Fit data & transcripts
│   ├── repositories/      # Local caching, config loaders, process execution
│   └── services/          # OAuth client, HTTP client
├── domain/
│   ├── entities/          # Pure models for steps, sleep, heart rate, process nodes
│   └── repositories/      # Interfaces
└── presentation/
    ├── providers/         # Riverpod providers (auth, metrics, CLI, process tree)
    └── widgets/           # Glassmorphic dashboard, Health metrics charts, Chat window, Node tree graph
```

## Milestones

### Implementation Track
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Project Init | Initialize desktop project, directory structure, window_manager configuration | None | DONE |
| M2 | Google OAuth & Fit REST API | OAuth 2.0 loopback, local config.json parser, Google Fit metrics fetching & local caching | M1 | DONE |
| M3 | CLI Wrapper & Monitoring | Process wrapper for `agy`, path resolution, stream parser, JSONL log parser for subagent trees | M1 | DONE |
| M4 | Glassmorphic Dashboard & Chat UI | Glassmorphism widgets, health charts, chat interface, interactive process tree graph | M2, M3 | IN_PROGRESS |
| M5 | E2E Integration & Verification | Run full E2E test suite (Tiers 1-4) and perform Phase 2 Adversarial Hardening (Tier 5) | M4, TEST_READY | PLANNED |

### E2E Testing Track
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| T1 | Test Infrastructure & Cases | Define test runner, Tier 1-4 tests (Feature, Boundary, Combinatorial, Workload), generate `TEST_READY.md` | None | DONE |

## Interface Contracts

### config.json Format
```json
{
  "client_id": "YOUR_CLIENT_ID.apps.googleusercontent.com",
  "client_secret": "YOUR_CLIENT_SECRET",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

### JSONL Log Format (from `~/.gemini/antigravity-cli/brain/*.jsonl`)
Each line is a JSON object with:
- `timestamp`: UTC ISO8601 string
- `agent_id`: unique ID of the agent
- `parent_id`: ID of the parent agent (null for root orchestrator)
- `state`: "Thinking" | "Running Command" | "Completed" | "Failed"
- `log`: optional text stream from stdout/stderr

### Health Metric Cache Scheme (local JSON or SQLite)
- Steps: `{"date": "YYYY-MM-DD", "count": 10000}`
- Sleep: `{"date": "YYYY-MM-DD", "duration_seconds": 28800}`
- Heart Rate: `{"timestamp": "ISO8601", "bpm": 72}`

## Code Layout
The project must adhere to the standard clean architecture layout described above. All files, assets, and configs will be managed surgically.
