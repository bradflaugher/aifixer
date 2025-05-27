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
        return 1
    fi
    
    # Remove whitespace and check length
    trimmed=$(echo "$content" | tr -d '[:space:]')
    length=${#trimmed}
    
    # Check if it's just error messages or common failure patterns first
    # (before length check to catch short error responses)
    if echo "$content" | grep -qE "^[[:space:]]*(error|Error|ERROR|null|undefined|None|\{\}|\[\])[[:space:]]*$"; then
        return 1
    fi
    
    # Check for responses that look like incomplete JSON or cut-off responses
    if echo "$content" | grep -qE "^[[:space:]]*\{[^}]*$|^[[:space:]]*\[[^\]]*$"; then
        return 1
    fi
    
    # Check if response appears to be cut off mid-sentence or mid-word
    # Look for responses that don't end with proper punctuation or complete words
    last_line=$(echo "$content" | tail -n 1)
    if echo "$last_line" | grep -qE "[a-zA-Z]$" && ! echo "$last_line" | grep -qE '\.$|!$|\?$|:$|;$|\)$|"$|'"'"'$'; then
        # Check if it's a very short last line that might be cut off
        last_line_length=${#last_line}
        if [ $last_line_length -lt 50 ]; then
            return 1
        fi
    fi
    
    if [ $length -lt $MIN_VALID_RESPONSE_LENGTH ]; then
        return 1
    fi
    
    # Check for common API error patterns
    if echo "$content" | grep -qiE "(api error|rate limit|quota exceeded|unauthorized|forbidden|internal server error)"; then
        return 1
    fi
    
    # Check for responses that are just whitespace or newlines
    if [ "$length" -eq 0 ]; then
        return 1
    fi
    
    return 0
}

# ─── Model Listing & Selection ───────────────────────────────────────────────────

fetch_openrouter_models() {
    echo "Fetching OpenRouter models..." >&2
    
    tmpfile="/tmp/aifixer_models_response_$$"
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

process_with_openrouter() {
    api_key="$1"
    model="$2"
    prompt="$3"
    input_text="$4"
    
    
    full_prompt=$(build_fix_prompt "$prompt")
    full_prompt="${full_prompt}${input_text}"
    
    
    # Build JSON payload
    escaped_prompt=$(escape_json_string "$full_prompt")
    payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "temperature": 0.7}' \
        "$model" "$escaped_prompt")
    
    response=$(curl -s -m $REQUEST_TIMEOUT \
        -H "Authorization: Bearer $api_key" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OPENROUTER_URL/chat/completions" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Request failed"
        return 1
    fi
    
    # Check for error in response
    if echo "$response" | grep -q '"error"'; then
        error_msg=$(parse_json_value "$response" "message")
        if [ -z "$error_msg" ]; then
            error_msg=$(echo "$response" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//')
        fi
        log_error "API error: ${error_msg:-Unknown error}"
        return 1
    fi
    
    # Extract content from choices array using awk for robust JSON parsing
    content=$(echo "$response" | awk '
        BEGIN { 
            in_content = 0; 
            content = "";
            escape_mode = 0;
        }
        {
            line = $0;
            if (in_content == 0 && match(line, /"content"[[:space:]]*:[[:space:]]*"/)) {
                # Found content field, start extracting after the opening quote
                in_content = 1;
                start = RSTART + RLENGTH;
                line = substr(line, start);
            }
            
            if (in_content == 1) {
                # Process character by character to handle escapes properly
                for (i = 1; i <= length(line); i++) {
                    c = substr(line, i, 1);
                    
                    if (escape_mode == 1) {
                        # Handle escaped characters
                        if (c == "n") content = content "\n";
                        else if (c == "t") content = content "\t";
                        else if (c == "\"") content = content "\"";
                        else if (c == "\\") content = content "\\";
                        else if (c == "r") content = content "\r";
                        else content = content c;
                        escape_mode = 0;
                    } else if (c == "\\") {
                        escape_mode = 1;
                    } else if (c == "\"") {
                        # Found closing quote
                        in_content = 2;
                        exit;
                    } else {
                        content = content c;
                    }
                }
                if (in_content == 1) content = content "\n";
            }
        }
        END { 
            print content; 
        }
    ')
    
    
    
    # Validate response
    if ! is_valid_response "$content"; then
        return 1
    fi
    
    echo "$content"
}

process_with_ollama() {
    model="$1"
    prompt="$2"
    input_text="$3"
    
    full_prompt=$(build_fix_prompt "$prompt")
    full_prompt="${full_prompt}${input_text}"
    
    # Build JSON payload
    escaped_prompt=$(escape_json_string "$full_prompt")
    payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "stream": false}' \
        "$model" "$escaped_prompt")
    
    
    response=$(curl -s -m $REQUEST_TIMEOUT \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OLLAMA_URL/chat" 2>/dev/null)
    
    curl_exit_code=$?
    if [ $curl_exit_code -ne 0 ]; then
        log_error "Cannot connect to Ollama at $OLLAMA_URL (exit code: $curl_exit_code)"
        exit 1
    fi
    
    
    # Extract content from Ollama response using awk for robust JSON parsing
    content=$(echo "$response" | awk '
        BEGIN { 
            in_content = 0; 
            content = "";
            escape_mode = 0;
        }
        {
            line = $0;
            if (in_content == 0 && match(line, /"content"[[:space:]]*:[[:space:]]*"/)) {
                # Found content field, start extracting after the opening quote
                in_content = 1;
                start = RSTART + RLENGTH;
                line = substr(line, start);
            }
            
            if (in_content == 1) {
                # Process character by character to handle escapes properly
                for (i = 1; i <= length(line); i++) {
                    c = substr(line, i, 1);
                    
                    if (escape_mode == 1) {
                        # Handle escaped characters
                        if (c == "n") content = content "\n";
                        else if (c == "t") content = content "\t";
                        else if (c == "\"") content = content "\"";
                        else if (c == "\\") content = content "\\";
                        else if (c == "r") content = content "\r";
                        else content = content c;
                        escape_mode = 0;
                    } else if (c == "\\") {
                        escape_mode = 1;
                    } else if (c == "\"") {
                        # Found closing quote
                        in_content = 2;
                        exit;
                    } else {
                        content = content c;
                    }
                }
                if (in_content == 1) content = content "\n";
            }
        }
        END { 
            print content; 
        }
    ')
    
    if [ -z "$content" ]; then
        log_error "Failed to extract content from Ollama response"
    fi
    
    echo "$content"
}

# ─── TODO File Analysis ────────────────────────────────────────────────────────


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
        tmpfile="/tmp/aifixer_result_$$"
        (
            result=$(process_with_ollama "$current_model" "$PROMPT" "$input_text")
            echo "$result" > "$tmpfile"
        ) &
        spinner "Processing via Ollama ($current_model)..." $!
        result=$(cat "$tmpfile" 2>/dev/null)
        rm -f "$tmpfile"
        success=1
    else
        # Try primary model first
        tmpfile_result="/tmp/aifixer_result_$$"
        tmpfile_status="/tmp/aifixer_status_$$"
        (
            result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text")
            echo "$?" > "$tmpfile_status"
            echo "$result" > "$tmpfile_result"
        ) &
        spinner "Processing via OpenRouter ($current_model)..." $!
        
        status=$(cat "$tmpfile_status" 2>/dev/null || echo "1")
        result=$(cat "$tmpfile_result" 2>/dev/null)
        rm -f "$tmpfile_status" "$tmpfile_result"
        
        # Check if primary model succeeded with valid response
        if [ "$status" -eq 0 ] && is_valid_response "$result"; then
            success=1
        else
            # Primary model failed or returned invalid response
            
            # Try fallback models if available
            if [ -n "$fallback_models" ]; then
                
                # Try fallback models (fixed: no subshell issue)
                while IFS= read -r model; do
                [ -z "$model" ] && continue
                current_model="$model"
                
                tmpfile_result="/tmp/aifixer_result_$$"
                tmpfile_status="/tmp/aifixer_status_$$"
                (
                    result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text")
                    echo "$?" > "$tmpfile_status"
                    echo "$result" > "$tmpfile_result"
                ) &
                spinner "Processing via OpenRouter ($current_model)..." $!
                
                status=$(cat "$tmpfile_status" 2>/dev/null || echo "1")
                result=$(cat "$tmpfile_result" 2>/dev/null)
                rm -f "$tmpfile_status" "$tmpfile_result"
                
                # Check if this model succeeded with valid response
                if [ "$status" -eq 0 ] && is_valid_response "$result"; then
                    success=1
                    break
                else
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
    
    # Output result
    echo "$result"
}

# Run main function
main "$@"
