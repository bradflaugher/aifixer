#!/usr/bin/env bash
# aifixer integration tests
# Requires: bash, grep, mktemp, aifixer in PATH
set -euo pipefail

# ─── Globals ──────────────────────────────────────────────────────────────────
TEST_COUNT=0
PASSED_COUNT=0
AIFIXER_CMD="aifixer"
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

if ! command_exists "$AIFIXER_CMD"; then
  echo "Error: '$AIFIXER_CMD' not found in PATH." >&2
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

if version_output=$($AIFIXER_CMD --version); then
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

if help_output=$($AIFIXER_CMD --help); then
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
  if ai_out=$("$AIFIXER_CMD" < "$f3"); then
    after_count=$(grep -c "TODO" <<<"$ai_out" || echo 0)
    if [[ $after_count -lt $before_count ]]; then
      print_result "PASS" "TODOs reduced ($before_count → $after_count)"
    else
      print_result "FAIL" "TODOs not reduced" "Before=$before_count, After=$after_count"
    fi
  else
    print_result "FAIL" "aifixer execution" "Non­zero exit code"
  fi
fi

# ─── Test 4: --list-todo-files (some TODOs) ───────────────────────────────────
print_header "Test 4: --list-todo-files (with TODOs)"

readonly TEST_CODE_4=$'# File: foo.py\nprint("ok")\n# File: bar.py\n# TODO: fix me\n'
f4=$(create_temp_file "$TEST_CODE_4")
if list_out=$("$AIFIXER_CMD" --list-todo-files < "$f4"); then
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
if no_list_out=$("$AIFIXER_CMD" --list-todo-files < "$f5"); then
  if [[ "$no_list_out" =~ ([Nn]o.*TODO) ]]; then
    print_result "PASS" "--list-todo-files reports none"
  else
    print_result "FAIL" "--list-todo-files expected 'no TODOs'" "Got: '$no_list_out'"
  fi
else
  print_result "FAIL" "--list-todo-files (none) failed"
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