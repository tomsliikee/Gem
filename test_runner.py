#!/usr/bin/env python3
"""
Automated Test Runner for Gem (Personal Life OS)
Executes unit/widget/E2E tests using 'flutter test --machine' and provides structured console output and report file.
"""

import sys
import os
import subprocess
import json
import time

def run_tests():
    print("==================================================")
    print("      Gem Life OS: Starting Test Suite            ")
    print("==================================================")

    # Resolve paths relative to script location
    project_dir = os.path.dirname(os.path.abspath(__file__))
    
    command = ["flutter", "test", "--machine"]
    
    try:
        # Start flutter test subprocess
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=project_dir
        )
    except FileNotFoundError:
        print("\n[ERROR] 'flutter' executable not found in PATH.")
        print("Please check your Flutter SDK setup.")
        sys.exit(2)

    tests_run = 0
    passed_tests = 0
    failed_tests = 0
    test_results = []
    current_tests = {}
    non_json_lines = []
    start_time = time.time()

    # Parse standard output stream of JSON lines
    try:
        for line in process.stdout:
            line = line.strip()
            if not line:
                continue
            
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                non_json_lines.append(line)
                continue # Skip non-json output if any

            event_type = event.get("event")
            
            if event_type == "testStart":
                test_info = event.get("test", {})
                test_id = test_info.get("id")
                test_name = test_info.get("name")
                # Exclude root loading/group events if they have no actual test run logic
                if test_name and not test_name.startswith("loading") and not test_name.endswith(".dart"):
                     current_tests[test_id] = test_name
                     tests_run += 1
            
            elif event_type == "testDone":
                test_id = event.get("testID")
                result = event.get("result")
                hidden = event.get("hidden", False)
                
                if test_id in current_tests and not hidden:
                    test_name = current_tests[test_id]
                    if result == "success":
                        passed_tests += 1
                        print(f"[\u2714 PASS] {test_name}")
                        test_results.append({"name": test_name, "status": "PASS", "duration": event.get("time")})
                    else:
                        failed_tests += 1
                        print(f"[\u2718 FAIL] {test_name}")
                        test_results.append({"name": test_name, "status": "FAIL", "duration": event.get("time")})
                        
    except KeyboardInterrupt:
        print("\n[WARNING] Execution interrupted by user. Terminating process...")
        process.terminate()
        sys.exit(1)

    return_code = process.wait()
    end_time = time.time()
    elapsed = round(end_time - start_time, 2)

    if return_code != 0 and tests_run == 0:
        print("\n======================= ERROR LOGS =======================")
        for err_line in non_json_lines:
            print(err_line)
        print("==========================================================\n")

    # Print summary metrics
    print("\n==================================================")
    print("              Test Execution Summary              ")
    print("==================================================")
    print(f"Total Tests Run: {tests_run}")
    print(f"Passed:          {passed_tests}")
    print(f"Failed:          {failed_tests}")
    print(f"Time Elapsed:    {elapsed} seconds")
    print("==================================================")

    # Write report file
    report = {
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "summary": {
            "total": tests_run,
            "passed": passed_tests,
            "failed": failed_tests,
            "duration_seconds": elapsed
        },
        "results": test_results
    }

    report_path = "/home/toms/projects/Gem/.agents/sub_orch_t1/test_report.json"
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
    print(f"Report written to: {report_path}\n")

    # Set exit status
    if failed_tests > 0 or tests_run == 0:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    run_tests()
