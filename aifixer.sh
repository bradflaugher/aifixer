#!/bin/sh
# aifixer.sh — Terminal‑native AI coding assistant POSIX compliant

set -eu

VERSION="2.0.0"
OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
REQUEST_TIMEOUT=60

# Default values
MODEL="anthropic/claude-sonnet-4"
PROMPT="Fix the TODOs in the file below and output the full file: "
MIN_VALID_RESPONSE_LENGTH=100  # Minimum characters for a valid response

# Use a more robust temp directory that works in multiuser environments
TMPDIR="${TMPDIR:-/tmp}"
# Add PID and random component for uniqueness in multiuser environment
TEMP_PREFIX="${TMPDIR}/aifixer_$$_$(od -An -N4 -tx /dev/urandom | tr -d ' ')"

# Color codes for output (disabled if not in terminal)
if [ -t 2 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# ─── Utility Functions ────────────────────────────────────────────────────────

log_error() {
    printf "${RED}ERROR: %s${NC}\n" "$*" >&2
}

log_debug() {
    # Add debug logging that works in headless environments
    if [ "${DEBUG:-0}" = "1" ]; then
        printf "DEBUG: %s\n" "$*" >&2
    fi
}

# JSON utilities for native shell parsing
parse_json_value() {
    json="$1"
    key="$2"
    # Extract value for a given key from JSON
    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed 's/,$//'
}

# Extract JSON array elements
parse_json_array() {
    json="$1"
    key="$2"
    # Extract array for a given key
    array_start="\"${key}\"[[:space:]]*:[[:space:]]*\["
    if echo "$json" | grep -q "$array_start"; then
        remaining=$(echo "$json" | sed "s/.*$array_start//")
        echo "$remaining" | sed 's/\].*$//' | tr ',' '\n' | sed 's/^[[:space:]]*"//' | sed 's/"[[:space:]]*$//'
    fi
}

# Escape string for JSON
escape_json_string() {
    str="$1"
    # Use sed for portable string replacement
    str=$(echo "$str" | sed 's/\\/\\\\/g')
    str=$(echo "$str" | sed 's/"/\\"/g')
    str=$(echo "$str" | sed 's/	/\\t/g')
    str=$(echo "$str" | sed ':a;N;$!ba;s/\n/\\n/g')
    echo "$str"
}

# Format bytes to human readable
format_size() {
    size=$1
    units="B KB MB GB TB"
    unit_idx=0
    
    while [ $size -ge 1024 ] && [ $unit_idx -lt 4 ]; do
        size=$((size / 1024))
        unit_idx=$((unit_idx + 1))
    done
    
    # Get unit name
    i=0
    for unit in $units; do
        if [ $i -eq $unit_idx ]; then
            echo "${size}${unit}"
            break
        fi
        i=$((i + 1))
    done
}

# Terminal spinner
spinner() {
    message="$1"
    pid=$2
    chars="/-\|"
    i=0
    
    # Only show spinner if stderr is a terminal
    if [ ! -t 2 ]; then
        wait $pid
        return
    fi
    
    while kill -0 $pid 2>/dev/null; do
        char=$(echo "$chars" | cut -c$((i + 1)))
        printf "\r%s %c " "$message" "$char" >&2
        i=$(( (i+1) % 4 ))
        sleep 0.1
    done
    # Clear line
    printf "\r%*s\r" $((${#message} + 4)) "" >&2
}


# Check if response is valid (not empty, not just whitespace, has minimum length)
is_valid_response() {
    content="$1"
    
    # Check if empty
    if [ -z "$content" ]; then
        log_debug "Response validation failed: empty content"
        return 1
    fi
    
    # Remove whitespace and check length
    trimmed=$(echo "$content" | tr -d '[:space:]')
    length=${#trimmed}
    
    # Check if it's just error messages or common failure patterns first
    # (before length check to catch short error responses)
    if echo "$content" | grep -qE "^[[:space:]]*(error|Error|ERROR|null|undefined|None|\{\}|\[\])[[:space:]]*$"; then
        log_debug "Response validation failed: error pattern detected"
        return 1
    fi
    
    # Check for responses that look like incomplete JSON or cut-off responses
    if echo "$content" | grep -qE "^[[:space:]]*\{[^}]*$|^[[:space:]]*\[[^\]]*$"; then
        log_debug "Response validation failed: incomplete JSON"
        return 1
    fi
    
    # Check if response appears to be cut off mid-sentence or mid-word
    # Look for responses that don't end with proper punctuation or complete words
    last_line=$(echo "$content" | tail -n 1)
    if echo "$last_line" | grep -qE "[a-zA-Z]$" && ! echo "$last_line" | grep -qE '\.$|!$|\?$|:$|;$|\)$|"$|'"'"'$'; then
        # Check if it's a very short last line that might be cut off
        last_line_length=${#last_line}
        if [ $last_line_length -lt 50 ]; then
            log_debug "Response validation failed: appears cut off"
            return 1
        fi
    fi
    
    if [ $length -lt $MIN_VALID_RESPONSE_LENGTH ]; then
        log_debug "Response validation failed: too short ($length < $MIN_VALID_RESPONSE_LENGTH)"
        return 1
    fi
    
    # Check for common API error patterns
    if echo "$content" | grep -qiE "(api error|rate limit|quota exceeded|unauthorized|forbidden|internal server error)"; then
        log_debug "Response validation failed: API error pattern"
        return 1
    fi
    
    # Check for responses that are just whitespace or newlines
    if [ "$length" -eq 0 ]; then
        log_debug "Response validation failed: only whitespace"
        return 1
    fi
    
    log_debug "Response validation passed"
    return 0
}

# ─── Model Listing & Selection ───────────────────────────────────────────────────

fetch_openrouter_models() {
    echo "Fetching OpenRouter models..." >&2
    
    tmpfile="${TEMP_PREFIX}_models_response"
    (
        curl -s -m $REQUEST_TIMEOUT "$OPENROUTER_URL/models" > "$tmpfile" 2>/dev/null
    ) &
    pid=$!
    spinner "Fetching models from OpenRouter..." $pid
    
    if [ ! -s "$tmpfile" ]; then
        log_error "Could not fetch OpenRouter models"
        rm -f "$tmpfile"
        exit 1
    fi
    
    # For now, just return models in API order (curated by OpenRouter)
    # Free models typically have ":free" suffix or very low prices
    # High-quality models like Claude and GPT-4 are usually listed early
    grep -o '{"id":"[^"]*"' "$tmpfile" | sed 's/{"id":"//' | sed 's/"$//'
    rm -f "$tmpfile"
}


fetch_ollama_models() {
    echo "Fetching Ollama models..." >&2
    
    response=$(curl -s -m $REQUEST_TIMEOUT "$OLLAMA_URL/tags" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to Ollama at $OLLAMA_URL"
        return
    fi
    
    # Parse Ollama models from response
    echo "$response" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//'
}

# ─── Processing Functions ─────────────────────────────────────────────────────

build_fix_prompt() {
    base_prompt="$1"
    
    echo "$base_prompt"
}

# Simplified JSON content extraction using sed
extract_json_content() {
    response="$1"
    
    # First try to extract content field from the response
    # This handles the nested structure of OpenRouter/Ollama responses
    content=$(echo "$response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
    
    # If that fails, try a more permissive pattern
    if [ -z "$content" ]; then
        # Look for content after "content": including escaped quotes
        content=$(echo "$response" | sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | sed 's/\\"/"/g' | sed 's/\\n/\
/g' | sed 's/\\t/	/g' | sed 's/\\\\/\\/g')
    fi
    
    echo "$content"
}

process_with_openrouter() {
    api_key="$1"
    model="$2"
    prompt="$3"
    input_text="$4"
    
    log_debug "Processing with OpenRouter model: $model"
    
    full_prompt=$(build_fix_prompt "$prompt")
    full_prompt="${full_prompt}${input_text}"
    
    # Build JSON payload
    escaped_prompt=$(escape_json_string "$full_prompt")
    payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "temperature": 0.7}' \
        "$model" "$escaped_prompt")
    
    # Create temp file for response
    response_file="${TEMP_PREFIX}_openrouter_response"
    
    # Make the API call and save to file
    log_debug "Making API call to OpenRouter..."
    curl -s -m $REQUEST_TIMEOUT \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OPENROUTER_URL/chat/completions" > "$response_file" 2>&1
    
    curl_exit=$?
    
    if [ $curl_exit -ne 0 ]; then
        log_error "Curl request failed with exit code: $curl_exit"
        rm -f "$response_file"
        return 1
    fi
    
    # Read response from file
    response=$(cat "$response_file")
    rm -f "$response_file"
    
    log_debug "Raw response length: ${#response}"
    
    # Check for error in response
    if echo "$response" | grep -q '"error"'; then
        error_msg=$(parse_json_value "$response" "message")
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$response" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//')
        fi
        log_error "API error: ${error_msg:-Unknown error}"
        return 1
    fi
    
    # Extract content using simplified method
    content=$(extract_json_content "$response")
    
    log_debug "Extracted content length: ${#content}"
    
    # Validate response
    if ! is_valid_response "$content"; then
        log_error "Invalid response from OpenRouter"
        return 1
    fi
    
    echo "$content"
}

process_with_ollama() {
    model="$1"
    prompt="$2"
    input_text="$3"
    
    log_debug "Processing with Ollama model: $model"
    
    full_prompt=$(build_fix_prompt "$prompt")
    full_prompt="${full_prompt}${input_text}"
    
    # Build JSON payload
    escaped_prompt=$(escape_json_string "$full_prompt")
    payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "stream": false}' \
        "$model" "$escaped_prompt")
    
    # Create temp file for response
    response_file="${TEMP_PREFIX}_ollama_response"
    
    # Make the API call and save to file
    log_debug "Making API call to Ollama..."
    curl -s -m $REQUEST_TIMEOUT \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OLLAMA_URL/chat" > "$response_file" 2>&1
    
    curl_exit_code=$?
    if [ $curl_exit_code -ne 0 ]; then
        log_error "Cannot connect to Ollama at $OLLAMA_URL (exit code: $curl_exit_code)"
        rm -f "$response_file"
        exit 1
    fi
    
    # Read response from file
    response=$(cat "$response_file")
    rm -f "$response_file"
    
    log_debug "Raw response length: ${#response}"
    
    # Extract content using simplified method
    content=$(extract_json_content "$response")
    
    log_debug "Extracted content length: ${#content}"
    
    if [ -z "$content" ]; then
        log_error "Failed to extract content from Ollama response"
        log_debug "First 500 chars of response: $(echo "$response" | head -c 500)"
        return 1
    fi
    
    echo "$content"
}

# ─── Help Functions ────────────────────────────────────────────────────────────

show_help() {
    cat << EOF
AIFixer — Terminal-native AI coding assistant

Usage: aifixer [OPTIONS] [TEXT...]

Options:
  --version                Show version
  --help-examples          Show usage examples

Model Selection:
  --model MODEL           Model to use (default: $MODEL)
  --ollama-model MODEL    Use Ollama model instead

Model Listing:
  --list-models           List OpenRouter models
  --list-ollama-models    List Ollama models

Prompt Options:
  --prompt TEXT           Custom prompt (default: Fix TODOs...)

Environment:
  OPENROUTER_API_KEY      Required for OpenRouter models
  DEBUG=1                 Enable debug output

EOF
}

show_examples() {
    cat << EOF
Examples:
  # Fix TODOs in a file
  cat file.py | aifixer --model anthropic/claude-3-sonnet > fixed.py
  
  # List available models
  aifixer --list-models
  
  # Use local Ollama
  cat main.go | aifixer --ollama-model codellama > fixed.go
  
  # Custom prompt
  cat complicated_program.c | aifixer --prompt "Please explain this code"

  # Debug mode
  DEBUG=1 cat file.py | aifixer > fixed.py 2>debug.log

EOF
}

# ─── Main ──────────────────────────────────────────────────────────────────────

main() {
    input_text=""
    ollama_model=""
    list_models=0
    list_ollama=0
    help_examples=0
    show_version=0
    text_args=""
    
    # Parse arguments
    while [ $# -gt 0 ]; do
        case $1 in
            --version)
                show_version=1
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            --help-examples)
                help_examples=1
                shift
                ;;
            --model)
                MODEL="$2"
                shift 2
                ;;
            --ollama-model)
                ollama_model="$2"
                shift 2
                ;;
            --list-models)
                list_models=1
                shift
                ;;
            --list-ollama-models)
                list_ollama=1
                shift
                ;;
            --prompt)
                PROMPT="$2"
                shift 2
                ;;
            --)
                shift
                while [ $# -gt 0 ]; do
                    text_args="$text_args $1"
                    shift
                done
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                text_args="$text_args $1"
                shift
                ;;
        esac
    done
    
    # Handle special actions
    if [ $show_version -eq 1 ]; then
        echo "$VERSION"
        exit 0
    fi
    
    if [ $help_examples -eq 1 ]; then
        show_examples
        exit 0
    fi
    
    if [ $list_models -eq 1 ]; then
        fetch_openrouter_models
        exit 0
    fi
    
    if [ $list_ollama -eq 1 ]; then
        fetch_ollama_models
        exit 0
    fi
    
    # Print version for interactive use
    if [ -t 2 ]; then
        echo "AIFixer v$VERSION" >&2
    fi
    
    # Get input text
    if [ -n "$text_args" ]; then
        input_text="$text_args"
    elif [ ! -t 0 ]; then
        input_text=$(cat)
    else
        # If no input but prompt was provided, use empty input
        if [ "$PROMPT" != "Fix the TODOs in the file below and output the full file: " ]; then
            input_text=""
        else
            show_help
            exit 0
        fi
    fi
    
    log_debug "Input text length: ${#input_text}"
    
    # Fallback models setup
    fallback_models=""
    
    # Check API key
    api_key="${OPENROUTER_API_KEY:-}"

    if [ -z "$ollama_model" ] && [ -z "$api_key" ]; then
        log_error "OPENROUTER_API_KEY not set; export it and retry."
        exit 1
    fi
    
    # Process the request
    start_time=$(date +%s)
    current_model="$MODEL"
    result=""
    success=0
    
    if [ -n "$ollama_model" ]; then
        current_model="$ollama_model"
        log_debug "Using Ollama model: $current_model"
        
        tmpfile="${TEMP_PREFIX}_result"
        tmpfile_status="${TEMP_PREFIX}_status"
        
        # Run in background and capture both result and status
        (
            result=$(process_with_ollama "$current_model" "$PROMPT" "$input_text" 2>&1)
            status=$?
            echo "$status" > "$tmpfile_status"
            echo "$result" > "$tmpfile"
        ) &
        pid=$!
        
        spinner "Processing via Ollama ($current_model)..." $pid
        
        # Read status and result
        status=$(cat "$tmpfile_status" 2>/dev/null || echo "1")
        result=$(cat "$tmpfile" 2>/dev/null)
        rm -f "$tmpfile" "$tmpfile_status"
        
        if [ "$status" -eq 0 ] && [ -n "$result" ]; then
            success=1
        else
            log_error "Ollama processing failed"
            log_debug "Status: $status"
            log_debug "Result: $result"
        fi
    else
        # Try primary model first
        log_debug "Using OpenRouter model: $current_model"
        
        tmpfile_result="${TEMP_PREFIX}_result"
        tmpfile_status="${TEMP_PREFIX}_status"
        
        (
            result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text" 2>&1)
            status=$?
            echo "$status" > "$tmpfile_status"
            echo "$result" > "$tmpfile_result"
        ) &
        pid=$!
        
        spinner "Processing via OpenRouter ($current_model)..." $pid
        
        status=$(cat "$tmpfile_status" 2>/dev/null || echo "1")
        result=$(cat "$tmpfile_result" 2>/dev/null)
        rm -f "$tmpfile_status" "$tmpfile_result"
        
        # Check if primary model succeeded with valid response
        if [ "$status" -eq 0 ] && is_valid_response "$result"; then
            success=1
        else
            # Primary model failed or returned invalid response
            log_error "OpenRouter processing failed"
            log_debug "Status: $status"
            log_debug "Result length: ${#result}"
            
            # Try fallback models if available
            if [ -n "$fallback_models" ]; then
                log_debug "Trying fallback models..."
                
                # Try fallback models
                while IFS= read -r model; do
                    [ -z "$model" ] && continue
                    current_model="$model"
                    log_debug "Trying fallback model: $current_model"
                    
                    tmpfile_result="${TEMP_PREFIX}_result"
                    tmpfile_status="${TEMP_PREFIX}_status"
                    (
                        result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text" 2>&1)
                        status=$?
                        echo "$status" > "$tmpfile_status"
                        echo "$result" > "$tmpfile_result"
                    ) &
                    pid=$!
                    
                    spinner "Processing via OpenRouter ($current_model)..." $pid
                    
                    status=$(cat "$tmpfile_status" 2>/dev/null || echo "1")
                    result=$(cat "$tmpfile_result" 2>/dev/null)
                    rm -f "$tmpfile_status" "$tmpfile_result"
                    
                    # Check if this model succeeded with valid response
                    if [ "$status" -eq 0 ] && is_valid_response "$result"; then
                        success=1
                        break
                    else
                        log_debug "Fallback model $current_model failed"
                        # Small delay before trying next model to avoid rate limits
                        sleep 1
                    fi
                done <<EOF
$fallback_models
EOF
            fi
        fi
    fi
    
    if [ $success -eq 0 ]; then
        log_error "All models failed or returned invalid responses"
        exit 1
    fi
    
    # Show completion message
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    if [ -t 2 ]; then
        echo "Completed in ${elapsed}s with $current_model ✓" >&2
    fi
    
    # Output result - this is the critical part!
    # Make sure result is properly output to stdout
    if [ -n "$result" ]; then
        echo "$result"
    else
        log_error "Result is empty!"
        exit 1
    fi
}

# Run main function
main "$@"
