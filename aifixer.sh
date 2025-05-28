#!/bin/sh
# aifixer.sh — Simplified terminal AI coding assistant (POSIX compliant)

set -eu

VERSION="2.1.0"
OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
REQUEST_TIMEOUT=60

# Default values
MODEL="${AIFIXER_MODEL:-anthropic/claude-3.5-sonnet}"
PROMPT="Fix the TODOs in the file below and output the full file: "

# Simple temp file handling
TMPDIR="${TMPDIR:-/tmp}"
TEMP_FILE="${TMPDIR}/aifixer_$$_response"

# Cleanup on exit
trap 'rm -f "$TEMP_FILE"' EXIT INT TERM

# ─── Core Functions ───────────────────────────────────────────────────────────

log_error() {
    printf "ERROR: %s\n" "$*" >&2
}

# Simplified JSON string escaping
escape_json() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | awk '{printf "%s\\n", $0}' | sed '$ s/\\n$//'
}

# Extract content from API response
extract_content() {
    # Simple extraction that handles both OpenRouter and Ollama responses
    sed -n 's/.*"content"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1 | \
    sed -e 's/\\n/\
/g' -e 's/\\t/	/g' -e 's/\\"/"/g' -e 's/\\\\/\\/g'
}

# Simple spinner for long operations
show_progress() {
    message="$1"
    pid="$2"
    
    # Skip spinner if not interactive
    if [ ! -t 2 ]; then
        wait "$pid"
        return
    fi
    
    printf "%s" "$message" >&2
    while kill -0 "$pid" 2>/dev/null; do
        printf "." >&2
        sleep 1
    done
    printf " done\n" >&2
}

# ─── API Functions ────────────────────────────────────────────────────────────

call_openrouter() {
    api_key="$1"
    model="$2"
    content="$3"
    
    payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}],"temperature":0.7}' \
        "$model" "$(escape_json "$content")")
    
    curl -s -m "$REQUEST_TIMEOUT" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OPENROUTER_URL/chat/completions" 2>/dev/null
}

call_ollama() {
    model="$1"
    content="$2"
    
    payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}],"stream":false}' \
        "$model" "$(escape_json "$content")")
    
    curl -s -m "$REQUEST_TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OLLAMA_URL/chat" 2>/dev/null
}

# ─── Model Listing ────────────────────────────────────────────────────────────

list_models() {
    provider="$1"
    
    if [ "$provider" = "openrouter" ]; then
        response=$(curl -s -m "$REQUEST_TIMEOUT" "$OPENROUTER_URL/models" 2>/dev/null)
        if [ -n "$response" ]; then
            echo "$response" | grep -o '"id":"[^"]*"' | sed 's/"id":"//' | sed 's/"$//'
        else
            log_error "Failed to fetch OpenRouter models"
            return 1
        fi
    elif [ "$provider" = "ollama" ]; then
        response=$(curl -s -m "$REQUEST_TIMEOUT" "$OLLAMA_URL/tags" 2>/dev/null)
        if [ -n "$response" ]; then
            echo "$response" | grep -o '"name":"[^"]*"' | sed 's/"name":"//' | sed 's/"$//'
        else
            log_error "Failed to fetch Ollama models (is Ollama running?)"
            return 1
        fi
    fi
}

# ─── Main Processing ──────────────────────────────────────────────────────────

process_input() {
    provider="$1"
    model="$2"
    prompt="$3"
    input_text="$4"
    api_key="${5:-}"
    
    # Combine prompt and input
    full_content="$prompt$input_text"
    
    # Make API call in background
    if [ "$provider" = "ollama" ]; then
        (call_ollama "$model" "$full_content" > "$TEMP_FILE" 2>&1) &
    else
        (call_openrouter "$api_key" "$model" "$full_content" > "$TEMP_FILE" 2>&1) &
    fi
    
    pid=$!
    show_progress "Processing with $model" "$pid"
    wait "$pid"
    status=$?
    
    if [ $status -ne 0 ] || [ ! -s "$TEMP_FILE" ]; then
        log_error "API call failed"
        return 1
    fi
    
    # Check for API errors
    if grep -q '"error"' "$TEMP_FILE"; then
        error_msg=$(grep -o '"message":"[^"]*"' "$TEMP_FILE" | sed 's/"message":"//' | sed 's/"$//')
        log_error "API error: ${error_msg:-Unknown error}"
        return 1
    fi
    
    # Extract and output content
    content=$(cat "$TEMP_FILE" | extract_content)
    
    if [ -z "$content" ]; then
        log_error "Empty response from API"
        return 1
    fi
    
    echo "$content"
}

# ─── Help Functions ───────────────────────────────────────────────────────────

show_help() {
    cat << EOF
AIFixer v$VERSION — Terminal AI coding assistant

Usage: aifixer [OPTIONS] [TEXT...]

Options:
  -h, --help              Show this help
  -v, --version           Show version
  -m, --model MODEL       Model to use (default: $MODEL)
  -o, --ollama MODEL      Use Ollama model
  -p, --prompt TEXT       Custom prompt
  -l, --list              List OpenRouter models
  --list-ollama           List Ollama models

Environment:
  OPENROUTER_API_KEY      Required for OpenRouter models
  AIFIXER_MODEL           Default model (currently: $MODEL)

Examples:
  # Fix TODOs in a file
  cat file.py | aifixer > fixed.py
  
  # Use Ollama
  cat main.go | aifixer -o codellama > fixed.go
  
  # Custom prompt
  echo "What is 2+2?" | aifixer -p "Answer: "
EOF
}

# ─── Main ─────────────────────────────────────────────────────────────────────

main() {
    # Parse arguments
    ollama_model=""
    custom_prompt=""
    text_args=""
    
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "$VERSION"
                exit 0
                ;;
            -m|--model)
                MODEL="$2"
                shift 2
                ;;
            -o|--ollama)
                ollama_model="$2"
                shift 2
                ;;
            -p|--prompt)
                custom_prompt="$2"
                shift 2
                ;;
            -l|--list)
                list_models "openrouter"
                exit $?
                ;;
            --list-ollama)
                list_models "ollama"
                exit $?
                ;;
            --)
                shift
                text_args="$*"
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                exit 1
                ;;
            *)
                text_args="$text_args $1"
                shift
                ;;
        esac
    done
    
    # Set prompt
    if [ -n "$custom_prompt" ]; then
        PROMPT="$custom_prompt"
    fi
    
    # Get input
    if [ -n "$text_args" ]; then
        input_text="$text_args"
    elif [ ! -t 0 ]; then
        input_text=$(cat)
    else
        if [ -z "$custom_prompt" ]; then
            show_help
            exit 0
        fi
        input_text=""
    fi
    
    # Determine provider and model
    if [ -n "$ollama_model" ]; then
        provider="ollama"
        model="$ollama_model"
        api_key=""
    else
        provider="openrouter"
        model="$MODEL"
        api_key="${OPENROUTER_API_KEY:-}"
        
        if [ -z "$api_key" ]; then
            log_error "OPENROUTER_API_KEY not set"
            exit 1
        fi
    fi
    
    # Process the input
    start_time=$(date +%s 2>/dev/null || echo 0)
    
    if ! process_input "$provider" "$model" "$PROMPT" "$input_text" "$api_key"; then
        exit 1
    fi
    
    # Show completion time if interactive
    if [ -t 2 ] && [ "$start_time" != "0" ]; then
        end_time=$(date +%s 2>/dev/null || echo 0)
        if [ "$end_time" != "0" ]; then
            elapsed=$((end_time - start_time))
            printf "✓ Completed in %ds\n" "$elapsed" >&2
        fi
    fi
}

# Run main
main "$@"
