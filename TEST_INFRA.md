# E2E Test Infra: Gem (Personal Life OS & Antigravity Assistant)

This document describes the test architecture, feature inventory, UI key mappings, and test cases for Gem.

## 1. Test Philosophy & Architecture

Gem's testing strategy uses a dual-level approach:
1. **Opaque-Box E2E / Integration Tests**: Simulates user interactions with the application using standard widgets, validating that all components work together seamlessly. To ensure portability in CI/CD and headless environments, E2E tests are implemented as high-level widget integration tests using Flutter's testing framework, mocking external boundaries (OAuth server responses, Google Fit REST API data, and the `agy` CLI process execution).
2. **Unit & Widget Tests**: Tests individual classes, models, log parsing logic, config loaders, and specific widget states in isolation.

### Directory Layout
```
test/
├── config_loader_test.dart       # Unit: Validates config.json parser & error cases
├── fit_models_test.dart          # Unit: Validates steps, sleep, and heart rate serialization
├── transcript_parser_test.dart   # Unit: Validates brain log JSONL parsing and streaming
├── auth_provider_test.dart       # Unit/Widget: Validates Riverpod auth states
├── fit_provider_test.dart        # Unit/Widget: Validates Fit API fetching, local caching, offline fallback
├── widget_test.dart              # Widget: Validates layouts and basic UI components
├── challenger_test.dart          # Widget: Window manager gesture tests
├── mocks/                        # Mock implementations for infrastructure
│   ├── mock_oauth_service.dart   # Fake Google OAuth service & loopback
│   ├── mock_fit_client.dart      # Mock HTTP client for Fit REST payloads
│   └── mock_agy_process.dart     # Fake process runner for agy CLI
└── e2e/                           # E2E / Integration tests (Tiers 1-4)
    ├── tier1_feature_test.dart   # E2E: Happy path feature coverage (25 tests)
    ├── tier2_boundary_test.dart  # E2E: Boundary and corner cases (25 tests)
    ├── tier3_combination_test.dart # E2E: Pairwise cross-feature combinations (5 tests)
    └── tier4_application_test.dart # E2E: Real-world application scenarios (5 tests)
```

### UI Keys Interface Contract
To keep E2E tests decoupled from visual design changes, the implementation MUST use the following keys for widget lookup:

| Widget Key | Type | Description |
|---|---|---|
| `Key('window_minimize')` | Custom Window | Minimize window button |
| `Key('window_maximize')` | Custom Window | Maximize window button |
| `Key('window_close')` | Custom Window | Close window button |
| `Key('login_button')` | Authentication | Initiates Google OAuth flow |
| `Key('logout_button')` | Authentication | Clears credentials and logs out |
| `Key('chat_input')` | Chat UI | User prompt text field |
| `Key('chat_send_button')` | Chat UI | Sends message to `agy` |
| `Key('agy_path_override')` | Settings | Text field for custom `agy` path |
| `Key('settings_button')` | Dashboard | Toggles Settings drawer/view |
| `Key('tab_overview')` | Navigation | Selects Overview dashboard view |
| `Key('tab_health')` | Navigation | Selects Google Fit health metrics view |
| `Key('tab_chat')` | Navigation | Selects Antigravity CLI chat view |
| `Key('steps_chart')` | Health | Widget displaying step counts |
| `Key('sleep_chart')` | Health | Widget displaying sleep duration |
| `Key('heart_rate_chart')` | Health | Widget displaying heart rate history |
| `Key('agent_tree_visualizer')` | Chat UI | Node graph of active subagents |
| `Key('node_<agent_id>')` | Chat UI | Specific subagent node in process tree |
| `Key('node_logs_view')` | Chat UI | Detailed logs view for selected subagent node |

---

## 2. Feature Inventory

| Feature | Key | Requirement ID |
|---|---|---|
| Glassmorphic UI/State Management | F1 | R1 |
| Google OAuth 2.0 Loopback | F2 | R2 |
| Google Fit API Fetching/Caching | F3 | R2 |
| Antigravity CLI Chat Wrapper | F4 | R3 |
| Agent Process Tree Visualizer | F5 | R3 |

---

## 3. Test Cases List

### Tier 1: Feature Coverage (25 tests)
- **F1.1**: UI renders translucent panels, blur, shadows, and smooth theme transitions.
- **F1.2**: Custom window minimize button triggers window minimization.
- **F1.3**: Custom window maximize button toggles window maximization.
- **F1.4**: Custom window close button triggers app close.
- **F1.5**: App loads all primary tabs (Overview, Health, Chat) with correct default states.
- **F2.1**: OAuth flow is initiated upon clicking the login button when config is present.
- **F2.2**: Local redirect loopback server starts on port and captures redirect URL.
- **F2.3**: Successful login caches tokens locally and transitions state to Authenticated.
- **F2.4**: Riverpod auth provider updates reactive state and propagates to dashboard.
- **F2.5**: Logout button clears secure storage and redirects to unauthenticated view.
- **F3.1**: Google Fit steps data is retrieved from REST API and cached locally.
- **F3.2**: Google Fit sleep duration data is retrieved from REST API and cached locally.
- **F3.3**: Google Fit heart rate history data is retrieved from REST API and cached.
- **F3.4**: Steps, sleep, and heart rate charts are correctly populated and rendered.
- **F3.5**: Offline mode uses locally cached data when Fit API calls fail.
- **F4.1**: Chat UI is able to run the local `agy` executable from system PATH.
- **F4.2**: User message is correctly piped to `agy` stdin.
- **F4.3**: Streamed output from `agy` stdout is dynamically appended as chat bubbles.
- **F4.4**: Settings page path override is saved and updates execution path.
- **F4.5**: Invalid CLI path override displays visual error notification.
- **F5.1**: Process tree visualizer correctly loads the root agent node.
- **F5.2**: Spawned subagents are parsed from JSONL brain transcripts and added to tree.
- **F5.3**: Visual nodes transition colors/labels matching agent state updates (Thinking, Running Command, Completed, Failed).
- **F5.4**: Clicking on an agent node renders the detailed logs view.
- **F5.5**: Visualizer monitors and re-reads the JSONL files in real-time.

### Tier 2: Boundary & Corner Cases (25 tests)
- **F1.B1**: Window resized to micro dimensions (e.g. 200x200) behaves gracefully without overflow crashes.
- **F1.B2**: SQLite/drift database file corruption handles errors and falls back to empty defaults.
- **F1.B3**: Rapid repeated clicks on window controls do not cause race conditions or crashes.
- **F1.B4**: UI scales properly under extreme DPI settings.
- **F1.B5**: Missing system fonts fall back gracefully to standard sans-serif.
- **F2.B1**: Missing `config.json` yields a clear error popup asking to configure OAuth.
- **F2.B2**: Malformed `config.json` prints diagnostic error and blocks login.
- **F2.B3**: Empty `client_id` or `client_secret` in config yields configuration validation error.
- **F2.B4**: OAuth login timeout (e.g. user takes >5 minutes) triggers login cancel/timeout state.
- **F2.B5**: Loopback server port conflict (e.g. 8080 busy) switches to an ephemeral port.
- **F3.B1**: API returns empty dataset for range, UI charts render empty/no-data placeholder.
- **F3.B2**: Fit API returns HTTP 401 Unauthorized, app automatically initiates token refresh.
- **F3.B3**: Fit API returns HTTP 500 Internal Error, UI displays "Sync Error" but keeps cached data.
- **F3.B4**: Cache limits are enforced: old data (>30 days) is cleaned up, maintaining cache health.
- **F3.B5**: Fit API returns extreme values (1M steps, 25hr sleep, 300 bpm), models sanitize or bound data.
- **F4.B1**: `agy` binary not found in PATH or settings, app presents "Assistant Setup Guide".
- **F4.B2**: Huge prompt payload (>1MB file paste) handled efficiently without UI freeze.
- **F4.B3**: `agy` process crashes or exits with non-zero code, chat displays error bubble.
- **F4.B4**: User clicks "Stop" button, app terminates `agy` process tree and processes zombie nodes.
- **F4.B5**: Input contains shell metacharacters, process wrapper prevents shell injection.
- **F5.B1**: Transcript directory `~/.gemini/antigravity-cli/brain/` is missing, visualizer handles gracefully.
- **F5.B2**: Massive JSONL file (>10k lines) does not freeze the rendering thread.
- **F5.B3**: Malformed JSON line in transcript (truncated line) is skipped with a warning.
- **F5.B4**: Missing parent ID or circular tree relationships in log, graph resolves to flat list or handles cleanly.
- **F5.B5**: Rapid concurrent updates to transcript file are debounced for UI stability.

### Tier 3: Pairwise Cross-Feature Combinations (5 tests)
- **T3.1**: Executing an `agy` command and parsing subagents in real-time works concurrently with Google Fit data sync and rendering on the dashboard.
- **T3.2**: Google Fit cache refresh triggers visual updates while an active chat session streams CLI outputs.
- **T3.3**: User logs out during an active CLI command, terminating the CLI process and clearing cached Fit metrics.
- **T3.4**: Setting an invalid `agy` path in settings throws error but keeps Google Fit data syncing and dashboard rendering functional.
- **T3.5**: Rapidly switching tabs between Health, Chat, and Overview while API requests and CLI commands run does not cause memory leaks or state corruption.

### Tier 4: Real-World Application Scenarios (5 tests)
- **T4.1 (Happy Path)**: Clean startup, user inputs Google credentials, fetches steps/sleep/heart rate, navigates to chat, starts a prompt, CLI spawns subagent, visualizer renders tree, and output streams to completion.
- **T4.2 (Offline Loop)**: Startup offline, dashboard displays cached data, user runs local chat command (e.g. offline help), goes online, OAuth token refreshes, new Fit data syncs, and dashboard updates.
- **T4.3 (Fault Recovery)**: First startup fails due to missing `config.json` and missing `agy` PATH. User writes `config.json`, inputs correct CLI path, authenticates, and app enters fully operational state.
- **T4.4 (Subagent Failure)**: User runs a complex task, CLI spawns subagents, one subagent fails (state: Failed in JSONL), process tree highlights the failed node, clicking the node shows its specific error logs, and the chat UI displays the failure message.
- **T4.5 (Multi-Day Health Analysis)**: Sync 30 days of data, steps goal is reached on 15 days, sleep is deficient on 5 days. Chat asks assistant "Analyze my activity logs", `agy` spawns subagent to query database cache, tree visualizer renders query agents, and chat returns sleep/activity correlation.
