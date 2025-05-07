#!/bin/bash

# AIFixer Test Script
# This script tests the basic functionalities of the aifixer tool.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration & Variables ---
TEST_COUNT=0
PASSED_COUNT=0
AIXIFER_CMD="aifixer"

# --- Helper Functions ---

# Function to print test headers
print_header() {
    echo ""
    echo "======================================================================="
    echo "$1"
    echo "======================================================================="
}

# Function to print pass/fail messages
print_result() {
    TEST_COUNT=$((TEST_COUNT + 1))
    if [ "$1" = "PASS" ]; then
        PASSED_COUNT=$((PASSED_COUNT + 1))
        echo -e "\033[32mPASS:\033[0m $2"
    else
        echo -e "\033[31mFAIL:\033[0m $2"
        if [ -n "$3" ]; then
            echo -e "      \033[31mReason:\033[0m $3"
        fi
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to create a temporary test file
create_temp_file() {
    local content="$1"
    local temp_file
    temp_file=$(mktemp /tmp/aifixer_test_XXXXXX.py)
    echo -e "$content" > "$temp_file"
    echo "$temp_file"
}

# --- Prerequisite Checks ---
print_header "Checking Prerequisites"

if ! command_exists "$AIXIFER_CMD"; then
    echo "Error: aifixer command not found. Please ensure it is installed and in your PATH." >&2
    exit 1
else
    echo "aifixer command found."
fi

OPENROUTER_API_KEY_SET=false
if [ -n "$OPENROUTER_API_KEY" ]; then
    OPENROUTER_API_KEY_SET=true
    echo "OPENROUTER_API_KEY is set."
else
    echo "Warning: OPENROUTER_API_KEY is not set. Tests requiring OpenRouter models may fail or be skipped."
fi

OLLAMA_RUNNING=false
if command_exists "ollama"; then
    # Simple check, assumes ollama ps would succeed if server is running and accessible
    # A more robust check might involve `ollama list` or `curl` to the Ollama API endpoint
    if ollama ps >/dev/null 2>&1; then
        OLLAMA_RUNNING=true
        echo "Ollama appears to be running."
    else
        echo "Warning: Ollama command exists, but the server doesn't seem to be running (ollama ps failed). Ollama tests may be skipped or fail."
    fi
elif curl --output /dev/null --silent --head --fail http://localhost:11434; then
    OLLAMA_RUNNING=true
    echo "Ollama API is accessible at http://localhost:11434."
else
    echo "Warning: Ollama command not found and Ollama API not accessible at http://localhost:11434. Ollama tests will be skipped."
fi

SPONGE_INSTALLED=false
if command_exists "sponge"; then
    SPONGE_INSTALLED=true
    echo "sponge (from moreutils) is installed."
else
    echo "Warning: sponge (from moreutils) is not installed. In-place editing test will be skipped."
fi

# --- Test Cases ---

print_header "Test Case 1: Basic TODO Fixing (Default Model - usually OpenRouter's free tier)"
TEST_FILE_CONTENT_1="# Python code\ndef hello():\n    # TODO: Implement this function to print hello world\n    pass"
EXPECTED_TODO_COUNT_BEFORE_1=1

test_file_1="$(create_temp_file "$TEST_FILE_CONTENT_1")"
echo "Created test file: $test_file_1 with content:"
cat "$test_file_1"

# Count TODOs before running aifixer
actual_todo_count_before_1=$(grep -c "TODO" "$test_file_1")

if [ "$actual_todo_count_before_1" -ne "$EXPECTED_TODO_COUNT_BEFORE_1" ]; then
    print_result "FAIL" "Test Case 1: Initial TODO count mismatch." "Expected $EXPECTED_TODO_COUNT_BEFORE_1, got $actual_todo_count_before_1"
else
    echo "Initial TODO count is correct: $actual_todo_count_before_1"
    # Run aifixer
    # Since AI output is non-deterministic, we check if the command runs and if TODOs are reduced.
    # We expect the default model to be an OpenRouter free model if API key is not set, or a default paid one if set.
    if output_1=$(cat "$test_file_1" | $AIXIFER_CMD 2>&1); then
        echo "aifixer ran successfully. Output:"
        echo "$output_1"
        # Check if output is not empty and if TODO count is reduced or eliminated
        if [ -n "$output_1" ]; then
            actual_todo_count_after_1=$(echo "$output_1" | grep -c "TODO")
            if [ "$actual_todo_count_after_1" -lt "$EXPECTED_TODO_COUNT_BEFORE_1" ]; then
                print_result "PASS" "Test Case 1: Basic TODO fixing seems to work (TODOs reduced)."
            else
                print_result "FAIL" "Test Case 1: TODO count did not decrease after running aifixer." "Before: $EXPECTED_TODO_COUNT_BEFORE_1, After: $actual_todo_count_after_1"
            fi
        else
            print_result "FAIL" "Test Case 1: aifixer produced empty output."
        fi
    else
        exit_code=$?
        print_result "FAIL" "Test Case 1: aifixer command failed." "Exit code: $exit_code. Output: $output_1"
    fi
fi
rm "$test_file_1"

# --- Summary ---
print_header "Test Summary"
echo "Total tests run: $TEST_COUNT"
echo "Tests passed: $PASSED_COUNT"

if [ "$PASSED_COUNT" -eq "$TEST_COUNT" ]; then
    echo -e "\033[32mAll tests passed!\033[0m"
    exit 0
else
    echo -e "\033[31mSome tests failed.\033[0m"
    exit 1
fi

