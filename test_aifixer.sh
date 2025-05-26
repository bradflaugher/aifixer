#!/usr/bin/env bash
# aifixer integration tests
# Requires: bash, grep, mktemp, aifixer in PATH
set -euo pipefail

# ─── Globals ──────────────────────────────────────────────────────────────────
TEST_COUNT=0
PASSED_COUNT=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AIFIXER_CMD="$SCRIPT_DIR/aifixer.sh"
TMPFILES=()

# ─── Cleanup ──────────────────────────────────────────────────────────────────
cleanup() {
  rm -f "${TMPFILES[@]:-}"
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
  local status=$1 msg=$2 reason=${3:-}
  TEST_COUNT=$((TEST_COUNT+1))
  if [[ $status == "PASS" ]]; then
    PASSED_COUNT=$((PASSED_COUNT+1))
    echo -e "\e[32mPASS:\e[0m $msg"
  else
    echo -e "\e[31mFAIL:\e[0m $msg"
    [[ -n $reason ]] && echo -e "      \e[31mReason:\e[0m $reason"
  fi
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

create_temp_file() {
  local content=$1
  local tmp
  tmp=$(mktemp /tmp/aifixer_test_XXXXXX.py)
  echo -e "$content" > "$tmp"
  TMPFILES+=("$tmp")
  echo "$tmp"
}

# ─── Prerequisite Checks ──────────────────────────────────────────────────────
print_header "Prerequisite Checks"

if [[ ! -f "$AIFIXER_CMD" ]]; then
  echo "Error: '$AIFIXER_CMD' not found." >&2
  exit 1
fi
echo "✔ Found '$AIFIXER_CMD'"

# OPENROUTER_API_KEY presence (warn only)
if [[ -z "${OPENROUTER_API_KEY:-}" ]]; then
  echo "Warning: OPENROUTER_API_KEY not set. OpenRouter‑based tests may fail."
else
  echo "✔ OPENROUTER_API_KEY is set"
fi

# ─── Test 1: --version ─────────────────────────────────────────────────────────
print_header "Test 1: --version"

if version_output=$(bash "$AIFIXER_CMD" --version); then
  if [[ $version_output =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_result "PASS" "--version prints semantic version ('$version_output')"
  else
    print_result "FAIL" "--version format" "Got '$version_output'"
  fi
else
  print_result "FAIL" "--version failed to run"
fi

# ─── Test 2: --help ────────────────────────────────────────────────────────────
print_header "Test 2: --help"

if help_output=$(bash "$AIFIXER_CMD" --help); then
  if grep -qi "usage:" <<<"$help_output"; then
    print_result "PASS" "--help shows usage"
  else
    print_result "FAIL" "--help content" "No 'usage:' in output"
  fi
else
  print_result "FAIL" "--help failed to run"
fi

# ─── Test 3: Basic TODO Fixing ──────────────────────────────────────────────────
print_header "Test 3: Basic TODO Removal"

readonly TEST_CODE_3=$'# File: hello.py\n# TODO: implement greet()\ndef greet():\n    pass\n'
f3=$(create_temp_file "$TEST_CODE_3")
before_count=$(grep -c "TODO" "$f3")

if [[ $before_count -ne 1 ]]; then
  print_result "FAIL" "Initial TODO count" "Expected 1, got $before_count"
else
  # Capture only stdout (AI result), let stderr go to console
  if ai_out=$(bash "$AIFIXER_CMD" < "$f3"); then
    print_count=$(grep -c "print" <<<"$ai_out" || echo 0)
    if [[ $print_count -gt 0 ]]; then
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

readonly TEST_CODE_4=$'# File: foo.py\nprint("ok")\n# File: bar.py\n# TODO: fix me\n'
f4=$(create_temp_file "$TEST_CODE_4")
if list_out=$(bash "$AIFIXER_CMD" --list-todo-files < "$f4"); then
  if grep -qx "bar.py" <<<"$list_out" && ! grep -qx "foo.py" <<<"$list_out"; then
    print_result "PASS" "--list-todo-files correctly listed 'bar.py'"
  else
    print_result "FAIL" "--list-todo-files content" "Got: $(echo "$list_out" | tr '\n' ' | ')"
  fi
else
  print_result "FAIL" "--list-todo-files failed"
fi

# ─── Test 5: --list-todo-files (no TODOs) ─────────────────────────────────────
print_header "Test 5: --list-todo-files (none)"

readonly TEST_CODE_5=$'# File: only.py\nprint("all good")\n'
f5=$(create_temp_file "$TEST_CODE_5")
if no_list_out=$(bash "$AIFIXER_CMD" --list-todo-files < "$f5"); then
  if [[ "$no_list_out" =~ ([Nn]o.*TODO) ]]; then
    print_result "PASS" "--list-todo-files reports none"
  else
    print_result "FAIL" "--list-todo-files expected 'no TODOs'" "Got: '$no_list_out'"
  fi
else
  print_result "FAIL" "--list-todo-files (none) failed"
fi

# ─── Test 6: --free Flag Testing ────────────────────────────────────────────────
print_header "Test 6: --free Flag"

readonly TEST_CODE_6=$'# File: free_test.py\n# TODO: implement a greeting function\ndef greet():\n    pass\n'
f6=$(create_temp_file "$TEST_CODE_6")

if free_out=$(bash "$AIFIXER_CMD" --free < "$f6" 2>&1); then
  # Check stderr output for model selection message
  if grep -q "Selected model:" <<<"$free_out"; then
    print_result "PASS" "--free selects model"
    
    # Capture only stdout (AI result)
    if ai_result=$(bash "$AIFIXER_CMD" --free < "$f6"); then
      # Check if the function implementation includes a 'print' statement
      print_count=$(grep -c "print" <<<"$ai_result" || echo 0)
      if [[ $print_count -gt 0 ]]; then
        print_result "PASS" "--free implementation contains print"
      else
        print_result "FAIL" "--free implementation" "No print statement found"
      fi
    else
      print_result "FAIL" "--free execution" "Non-zero exit code"
    fi
  else
    print_result "FAIL" "--free model selection" "No model selection message found"
  fi
else
  print_result "FAIL" "--free flag failed"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
print_header "Test Summary"
echo "Total tests run: $TEST_COUNT"
echo "Tests passed:     $PASSED_COUNT"

if [[ $PASSED_COUNT -eq $TEST_COUNT ]]; then
  echo -e "\e[32mAll tests passed!\e[0m"
  exit 0
else
  echo -e "\e[31mSome tests failed.\e[0m"
  exit 1
fi
