#!/bin/sh
# aifixer.sh — Terminal AI coding assistant (requires jq & curl)

set -eu

VERSION="3.0.0"
OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
REQUEST_TIMEOUT=60

# Default values
MODEL="${AIFIXER_MODEL:-anthropic/claude-3.5-sonnet}"
PROMPT="Fix the TODOs in the file below and output the full file: "

# ─── Core Functions ───────────────────────────────────────────────────────────

log_error() {
    printf "ERROR: %s\n" "$*" >&2
}

# Build JSON payload
build_payload() {
    model="$1"
    content="$2"
    
    jq -n \
        --arg model "$model" \
        --arg content "$content" \
        '{
            model: $model,
            messages: [{role: "user", content: $content}],
            temperature: 0.7
        }' | jq -c .
}

# Build Ollama payload
build_ollama_payload() {
    model="$1"
    content="$2"
    
    jq -n \
        --arg model "$model" \
        --arg content "$content" \
        '{
            model: $model,
            messages: [{role: "user", content: $content}],
            stream: false
        }' | jq -c .
}

# Simple progress indicator
show_progress() {
    if [ -t 2 ]; then
        printf "Processing with %s..." "$1" >&2
    fi
}

show_done() {
    if [ -t 2 ]; then
        printf " done\n" >&2
    fi
}

# ─── API Functions ────────────────────────────────────────────────────────────

call_openrouter() {
    api_key="$1"
    model="$2"
    content="$3"
    
    payload=$(build_payload "$model" "$content")
    
    curl -s -S -m "$REQUEST_TIMEOUT" \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OPENROUTER_URL/chat/completions"
}

call_ollama() {
    model="$1"
    content="$2"
    
    payload=$(build_ollama_payload "$model" "$content")
    
    curl -s -S -m "$REQUEST_TIMEOUT" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OLLAMA_URL/chat"
}

# Extract content from response
extract_content() {
    provider="$1"
    response="$2"
    
    if [ "$provider" = "ollama" ]; then
        echo "$response" | jq -r '.message.content // empty'
    else
        echo "$response" | jq -r '.choices[0].message.content // empty'
    fi
}

# Check for API error
check_error() {
    response="$1"
    echo "$response" | jq -r '.error.message // .error // empty'
}

# ─── Model Listing ────────────────────────────────────────────────────────────

list_models() {
    provider="$1"
    
    if [ "$provider" = "openrouter" ]; then
        curl -s -m "$REQUEST_TIMEOUT" "$OPENROUTER_URL/models" | \
            jq -r '.data[].id'
    else
        curl -s -m "$REQUEST_TIMEOUT" "$OLLAMA_URL/tags" | \
            jq -r '.models[].name'
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
    
    show_progress "$model"
    
    # Make API call
    if [ "$provider" = "ollama" ]; then
        response=$(call_ollama "$model" "$full_content")
    else
        response=$(call_openrouter "$api_key" "$model" "$full_content")
    fi
    
    show_done
    
    # Check for errors
    if [ -z "$response" ]; then
        log_error "Empty response from API"
        return 1
    fi
    
    error=$(check_error "$response")
    if [ -n "$error" ]; then
        log_error "API error: $error"
        return 1
    fi
    
    # Extract and output content
    content=$(extract_content "$provider" "$response")
    
    if [ -z "$content" ]; then
        log_error "No content in response"
        return 1
    fi
    
    printf '%s\n' "$content"
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
