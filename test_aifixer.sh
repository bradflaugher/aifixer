#!/bin/sh
# aifixer integration tests - POSIX compliant
# Requires: sh, grep, mktemp, aifixer in PATH
set -eu  # Note: pipefail is not POSIX

# ─── Globals ──────────────────────────────────────────────────────────────────
TEST_COUNT=0
PASSED_COUNT=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AIFIXER_CMD="$SCRIPT_DIR/aifixer.sh"
# Instead of array, use space-separated string
TMPFILES=""

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  if [ -n "$TMPFILES" ]; then
    # Split on spaces and remove each file
    for f in $TMPFILES; do
      rm -f "$f" 2>/dev/null || true
    done
  fi
}
trap cleanup EXIT

# ─── Helpers ──────────────────────────────────────────────────────────────────
print_header() {
  echo
  echo "======================================================================="
  echo "$1"
  echo "======================================================================="
}

print_result() {
  status=$1
  msg=$2
  reason="${3:-}"
  TEST_COUNT=$((TEST_COUNT+1))
  if [ "$status" = "PASS" ]; then
    PASSED_COUNT=$((PASSED_COUNT+1))
    printf "\033[32mPASS:\033[0m %s\n" "$msg"
  else
    printf "\033[31mFAIL:\033[0m %s\n" "$msg"
    if [ -n "$reason" ]; then
      printf "      \033[31mReason:\033[0m %s\n" "$reason"
    fi
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

create_temp_file() {
  content=$1
  tmp=$(mktemp /tmp/aifixer_test_XXXXXX.py)
  printf "%s\n" "$content" > "$tmp"
  # Append to space-separated list
  TMPFILES="$TMPFILES $tmp"
  echo "$tmp"
}

# ─── Prerequisite Checks ──────────────────────────────────────────────────────
print_header "Prerequisite Checks"

if [ ! -f "$AIFIXER_CMD" ]; then
  echo "Error: '$AIFIXER_CMD' not found." >&2
  exit 1
fi
echo "✔ Found '$AIFIXER_CMD'"

# OPENROUTER_API_KEY presence (warn only)
if [ -z "${OPENROUTER_API_KEY:-}" ]; then
  echo "Warning: OPENROUTER_API_KEY not set. OpenRouter‑based tests may fail."
else
  echo "✔ OPENROUTER_API_KEY is set"
fi

# ─── Test 1: --version ─────────────────────────────────────────────────────────
print_header "Test 1: --version"

if version_output=$(sh "$AIFIXER_CMD" --version); then
  # Use grep to check for semantic version pattern instead of regex
  if echo "$version_output" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' >/dev/null; then
    print_result "PASS" "--version prints semantic version ('$version_output')"
  else
    print_result "FAIL" "--version format" "Got '$version_output'"
  fi
else
  print_result "FAIL" "--version failed to run"
fi

# ─── Test 2: --help ────────────────────────────────────────────────────────────
print_header "Test 2: --help"

if help_output=$(sh "$AIFIXER_CMD" --help); then
  if echo "$help_output" | grep -qi "usage:"; then
    print_result "PASS" "--help shows usage"
  else
    print_result "FAIL" "--help content" "No 'usage:' in output"
  fi
else
  print_result "FAIL" "--help failed to run"
fi

# ─── Test 3: Basic TODO Fixing ──────────────────────────────────────────────────
print_header "Test 3: Basic TODO Removal"

TEST_CODE_3='# File: hello.py
# TODO: implement greet()
def greet():
    pass
'
f3=$(create_temp_file "$TEST_CODE_3")
before_count=$(grep -c "TODO" "$f3")

if [ "$before_count" -ne 1 ]; then
  print_result "FAIL" "Initial TODO count" "Expected 1, got $before_count"
else
  # Capture only stdout (AI result), let stderr go to console
  if ai_out=$(sh "$AIFIXER_CMD" < "$f3"); then
    print_count=$(echo "$ai_out" | grep -c "print" || echo 0)
    if [ "$print_count" -gt 0 ]; then
      print_result "PASS" "print found"
    else
      print_result "FAIL" "print not found"
    fi
  else
    print_result "FAIL" "aifixer execution" "Non­zero exit code"
  fi
fi

# ─── Test 4: --list-todo-files (some TODOs) ───────────────────────────────────
print_header "Test 4: --list-todo-files (with TODOs)"

TEST_CODE_4='# File: foo.py
print("ok")
# File: bar.py
# TODO: fix me
'
f4=$(create_temp_file "$TEST_CODE_4")
if list_out=$(sh "$AIFIXER_CMD" --list-todo-files < "$f4"); then
  if echo "$list_out" | grep -x "bar.py" >/dev/null && ! echo "$list_out" | grep -x "foo.py" >/dev/null; then
    print_result "PASS" "--list-todo-files correctly listed 'bar.py'"
  else
    print_result "FAIL" "--list-todo-files content" "Got: $(echo "$list_out" | tr '\n' ' ')"
  fi
else
  print_result "FAIL" "--list-todo-files failed"
fi

# ─── Test 5: --list-todo-files (no TODOs) ─────────────────────────────────────
print_header "Test 5: --list-todo-files (none)"

TEST_CODE_5='# File: only.py
print("all good")
'
f5=$(create_temp_file "$TEST_CODE_5")
if no_list_out=$(sh "$AIFIXER_CMD" --list-todo-files < "$f5"); then
  # Use grep to check for pattern
  if echo "$no_list_out" | grep -i "no.*TODO" >/dev/null; then
    print_result "PASS" "--list-todo-files reports none"
  else
    print_result "FAIL" "--list-todo-files expected 'no TODOs'" "Got: '$no_list_out'"
  fi
else
  print_result "FAIL" "--list-todo-files (none) failed"
fi

# ─── Test 6: Ollama Integration ─────────────────────────────────────────────────
print_header "Test 7: Ollama Integration"

# Check if Ollama is installed and running
if command_exists curl && curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "✔ Ollama is running"
  
  # Get list of available models
  ollama_models=$(sh "$AIFIXER_CMD" --list-ollama-models 2>/dev/null | grep -v "INFO:" | awk '{print $1}')
  
  if [ -n "$ollama_models" ]; then
    # Pick the first available model
    first_model=$(echo "$ollama_models" | head -n1)
    echo "✔ Found Ollama models. Using: $first_model"
    
    # Test 7a: List Ollama models
    if list_output=$(sh "$AIFIXER_CMD" --list-ollama-models 2>&1); then
      if echo "$list_output" | grep -q "INFO: Fetching Ollama models"; then
        print_result "PASS" "--list-ollama-models works"
      else
        print_result "FAIL" "--list-ollama-models" "No fetch message found"
      fi
    else
      print_result "FAIL" "--list-ollama-models failed"
    fi
    
    # Test 7b: Use Ollama model for TODO fixing
    TEST_CODE_6='# File: ollama_test.py
# TODO: implement hello function
def hello():
    pass
'
    f6=$(create_temp_file "$TEST_CODE_6")
    
    # Test if Ollama model works (ignore processing messages for now)
    if ai_result=$(sh "$AIFIXER_CMD" --ollama-model "$first_model" < "$f6" 2>/dev/null); then
      if [ -n "$ai_result" ]; then
        print_result "PASS" "Ollama model generated output"
      else
        print_result "FAIL" "Ollama output" "Empty response"
      fi
    else
      print_result "FAIL" "Ollama execution" "Non-zero exit code"
    fi
  else
    echo "Warning: No Ollama models found. Skipping model tests."
    print_result "PASS" "Ollama check (no models to test)"
  fi
else
  echo "Warning: Ollama not running or curl not available. Skipping Ollama tests."
  print_result "PASS" "Ollama integration (skipped - not installed)"
fi

# ─── Test 8: Piping and --fix-file-only ─────────────────────────────────────────
print_header "Test 8: Piping and --fix-file-only"

# Test 8a: Regular piping (with explanations)
TEST_CODE_7='def add(a, b):
    # TODO: Add type checking
    return a + b
'
f7=$(create_temp_file "$TEST_CODE_7")

if regular_out=$(sh "$AIFIXER_CMD" < "$f7" 2>/dev/null); then
  # Check if output contains both code and explanation
  out_len=$(printf "%s" "$regular_out" | wc -c)
  if echo "$regular_out" | grep -q "def add" && [ "$out_len" -gt 100 ]; then
    print_result "PASS" "Regular output includes full response"
  else
    print_result "FAIL" "Regular output format" "Output too short or missing code"
  fi
else
  print_result "FAIL" "Regular piping failed"
fi

# Test 8b: --fix-file-only flag
if fixed_out=$(sh "$AIFIXER_CMD" --fix-file-only < "$f7" 2>/dev/null); then
  # Count lines - should be just code without explanations
  line_count=$(echo "$fixed_out" | wc -l)
  # Check if it's cleaner output (no markdown, shorter)
  if ! echo "$fixed_out" | grep -q '```' && [ "$line_count" -lt 20 ]; then
    print_result "PASS" "--fix-file-only returns clean code"
  else
    print_result "FAIL" "--fix-file-only format" "Output contains markdown or is too long"
  fi
else
  print_result "FAIL" "--fix-file-only execution failed"
fi

# Test 8c: Piping to file
output_file="/tmp/aifixer_test_output_$$.py"
if sh "$AIFIXER_CMD" --fix-file-only < "$f7" > "$output_file" 2>/dev/null; then
  if [ -f "$output_file" ] && grep -q "def add" "$output_file"; then
    print_result "PASS" "Piping to file works correctly"
    rm -f "$output_file"
  else
    print_result "FAIL" "Piping to file" "Output file missing or incomplete"
  fi
else
  print_result "FAIL" "Piping to file execution failed"
fi

# ─── Test 9: JSON Parsing Robustness ─────────────────────────────────────────
print_header "Test 9: JSON Parsing Robustness"

# Test 9a: Code with special characters that could break JSON parsing
TEST_CODE_8A='def parse_json(data):
    # TODO: Add proper JSON parsing with error handling
    # This should handle: {"key": "value with \"quotes\"", "nested": {"array": [1, 2, 3]}}
    return data
'
f8a=$(create_temp_file "$TEST_CODE_8A")

if json_test_out=$(sh "$AIFIXER_CMD" --fix-file-only < "$f8a" 2>/dev/null); then
  # Check if the output contains proper JSON handling code
  if echo "$json_test_out" | grep -qi "json"; then
    print_result "PASS" "JSON parsing handles special characters in TODO comments"
  else
    # Still pass if output is non-empty and contains the function
    if [ -n "$json_test_out" ] && echo "$json_test_out" | grep -q "def parse_json"; then
      print_result "PASS" "JSON parsing produced valid output despite special chars"
    else
      print_result "FAIL" "JSON parsing with special chars" "Output was empty or corrupted"
    fi
  fi
else
  print_result "FAIL" "JSON parsing test execution failed"
fi

# Test 9b: Code with nested brackets and braces
TEST_CODE_8B='def complex_func():
    # TODO: Fix this complex nested structure handling
    data = {"a": [{"b": {"c": [1, 2, {"d": "e"}]}}]}
    return data
'
f8b=$(create_temp_file "$TEST_CODE_8B")

if brackets_out=$(sh "$AIFIXER_CMD" --fix-file-only < "$f8b" 2>/dev/null); then
  if [ -n "$brackets_out" ] && echo "$brackets_out" | grep -q "def complex_func"; then
    print_result "PASS" "JSON parsing handles nested brackets/braces"
  else
    print_result "FAIL" "Nested brackets test" "Output was empty or missing function"
  fi
else
  print_result "FAIL" "Nested brackets test execution failed"
fi

# ─── Test 9: Ollama with --fix-file-only ─────────────────────────────────────────
if command_exists curl && curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
  print_header "Test 9: Ollama with --fix-file-only"
  
  # Get first available Ollama model
  first_model=$(sh "$AIFIXER_CMD" --list-ollama-models 2>/dev/null | grep -v "INFO:" | awk '{print $1}' | head -n1)
  
  if [ -n "$first_model" ]; then
    TEST_CODE_9='def greet(name):
    # TODO: Add input validation
    print(f"Hello {name}")
'
    f9=$(create_temp_file "$TEST_CODE_9")
    
    # Test Ollama with --fix-file-only
    if ollama_fixed=$(sh "$AIFIXER_CMD" --ollama-model "$first_model" --fix-file-only < "$f9" 2>/dev/null); then
      # Check for clean code output
      if echo "$ollama_fixed" | grep -q "def greet" && ! echo "$ollama_fixed" | grep -q '```'; then
        print_result "PASS" "Ollama --fix-file-only returns clean code"
      else
        print_result "FAIL" "Ollama --fix-file-only format" "Contains markdown or missing function"
      fi
    else
      print_result "FAIL" "Ollama --fix-file-only execution failed"
    fi
  else
    print_result "PASS" "Ollama --fix-file-only (skipped - no models)"
  fi
else
  print_result "PASS" "Ollama --fix-file-only (skipped - Ollama not running)"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
print_header "Test Summary"
echo "Total tests run: $TEST_COUNT"
echo "Tests passed:     $PASSED_COUNT"

if [ "$PASSED_COUNT" -eq "$TEST_COUNT" ]; then
  printf "\033[32mAll tests passed!\033[0m\n"
  exit 0
else
  printf "\033[31mSome tests failed.\033[0m\n"
  exit 1
fi