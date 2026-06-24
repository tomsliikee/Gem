# TEST_READY: Gem Test Infrastructure & Verification Guide

This document details the completed test coverage, directories, layout, and instructions for running the test suite of the Gem project.

## 1. Test Coverage Overview

We have successfully implemented:
- **11 Unit & Widget Tests** covering configuration loading, health metric serialization, transcript log parsing, Riverpod state transitions, offline fallbacks, and window layout controls.
- **60 E2E Integration Tests** mapped across four distinct testing tiers using Flutter's widget testing framework and binding directly to the UI keys contract.

### Test Case Categorization

| Tier / Category | File Path | Total Tests | Expected Result | Description |
|---|---|---|---|---|
| **Unit: Config Loader** | `test/config_loader_test.dart` | 3 | **PASS** | Validates parsing of OAuth configuration and error handling. |
| **Unit: Health Models** | `test/fit_models_test.dart` | 3 | **PASS** | Telemetry serialization for steps, sleep, and heart rate. |
| **Unit: Transcript Parser** | `test/transcript_parser_test.dart` | 2 | **PASS** | Real-time JSONL parsing of subagent log streams. |
| **Unit: Auth Provider** | `test/auth_provider_test.dart` | 1 | **PASS** | Riverpod authentication state transitions. |
| **Unit: Fit Provider** | `test/fit_provider_test.dart` | 1 | **PASS** | Offline data caching and API failure fallback logic. |
| **Widget: Layout & Windows** | `test/widget_test.dart` | 2 | **PASS** | Custom title bar, window chrome, close/maximize actions. |
| **Widget: Gestures** | `test/challenger_test.dart` | 1 | **PASS** | Double-tap minimize button gesture propagation. |
| **E2E Tier 1: Feature Coverage** | `test/e2e/tier1_feature_test.dart` | 25 | **FAIL** | Happy path feature coverage. |
| **E2E Tier 2: Boundary/Corner Cases** | `test/e2e/tier2_boundary_test.dart` | 25 | **FAIL** | Edge cases and robust error boundaries. |
| **E2E Tier 3: Cross-Combinations** | `test/e2e/tier3_combination_test.dart` | 5 | **FAIL** | Concurrent features and pairwise combinations. |
| **E2E Tier 4: App Scenarios** | `test/e2e/tier4_application_test.dart` | 5 | **FAIL** | Real-world workload and recovery scenarios. |

*Note: E2E tests fail as expected (Finder errors) because they search for interactive UI keys that are not yet implemented in the skeleton layout. This validates that the tests act as strict, compile-ready contracts for subsequent milestones.*

---

## 2. Verification Instructions

To execute the test suite and verify the infrastructure, follow the instructions below.

### Method A: Python Test Runner (Recommended)
We have implemented a Python test runner script that executes tests in machine-readable format, streams live console feedback, writes a structured JSON report, and manages exit codes.

1. Run the test runner from the project root:
   ```bash
   python3 test_runner.py
   ```
2. The runner will stream each test result to the console.
3. Upon completion, the runner writes a detailed summary report to:
   ```
   .agents/sub_orch_t1/test_report.json
   ```

### Method B: Native Flutter CLI
You can also run all tests or individual tiers using the native Flutter test CLI:

- **Run all tests**:
  ```bash
  flutter test
  ```
- **Run only Unit & Widget tests**:
  ```bash
  flutter test test/config_loader_test.dart test/fit_models_test.dart test/transcript_parser_test.dart test/auth_provider_test.dart test/fit_provider_test.dart test/widget_test.dart test/challenger_test.dart
  ```
- **Run E2E Tier 1 Feature tests**:
  ```bash
  flutter test test/e2e/tier1_feature_test.dart
  ```
- **Run E2E Tier 2 Boundary tests**:
  ```bash
  flutter test test/e2e/tier2_boundary_test.dart
  ```
