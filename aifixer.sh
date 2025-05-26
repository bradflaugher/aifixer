#!/usr/bin/env bash
# aifixer.sh — Terminal‑native AI coding assistant (v1.1.0)

set -euo pipefail

VERSION="1.3.0"
OPENROUTER_URL="https://openrouter.ai/api/v1"
OLLAMA_URL="http://localhost:11434/api"
REQUEST_TIMEOUT=10

# Default values
MODEL="anthropic/claude-3-sonnet-20240229"
PROMPT="Fix the TODOs in the file below and output the full file: "
VERBOSE=0
DEBUG=0
FIX_FILE_ONLY=0
FREE=0
MAX_FALLBACKS=2
NUM_MODELS=20
SORT_BY="price"

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
    echo -e "${RED}ERROR: $*${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

log_info() {
    echo -e "${GREEN}INFO: $*${NC}" >&2
}

log_debug() {
    if [ $DEBUG -eq 1 ]; then
        echo -e "${BLUE}DEBUG: $*${NC}" >&2
    fi
}

# JSON utilities for native bash parsing
parse_json_value() {
    local json="$1"
    local key="$2"
    # Extract value for a given key from JSON
    echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[^,}]*" | sed -E 's/^"[^"]*"[[:space:]]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed 's/,$//'
}

# Extract JSON array elements
parse_json_array() {
    local json="$1"
    local key="$2"
    # Extract array for a given key
    local array_start="\"${key}\"[[:space:]]*:[[:space:]]*\["
    if [[ "$json" =~ $array_start ]]; then
        local remaining="${json#*$array_start}"
        echo "$remaining" | sed 's/\].*$//' | tr ',' '\n' | sed 's/^[[:space:]]*"//' | sed 's/"[[:space:]]*$//'
    fi
}

# Escape string for JSON
escape_json_string() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    echo "$str"
}

# Format bytes to human readable
format_size() {
    local size=$1
    local units=("B" "KB" "MB" "GB" "TB")
    local unit=0
    
    while [ $size -ge 1024 ] && [ $unit -lt 4 ]; do
        size=$((size / 1024))
        unit=$((unit + 1))
    done
    
    echo "${size}${units[$unit]}"
}

# Terminal spinner
spinner() {
    local message="$1"
    local pid=$2
    local chars="/-\|"
    local i=0
    
    # Only show spinner if stderr is a terminal
    if [ ! -t 2 ]; then
        wait $pid
        return
    fi
    
    while kill -0 $pid 2>/dev/null; do
        printf "\r%s %c " "$message" "${chars:$i:1}" >&2
        i=$(( (i+1) % 4 ))
        sleep 0.1
    done
    printf "\r%*s\r" $((${#message} + 4)) "" >&2
}

# Extract fixed file from AI output
extract_fixed_file() {
    local output="$1"
    
    # First try to extract from code blocks
    local code_block=$(echo "$output" | sed -n '/^```/,/^```$/p' | sed '1d;$d')
    if [ -n "$code_block" ]; then
        echo "$code_block"
        return
    fi
    
    # Otherwise, clean up the output
    echo "$output" | sed -E 's/^#+ .*$//' | sed '/^[[:space:]]*$/d'
}

# ─── Model Listing & Selection ───────────────────────────────────────────────────

fetch_openrouter_models() {
    local num=$1
    local sort_key=$2
    
    log_info "Fetching OpenRouter models..."
    
    local response=$(curl -s -m $REQUEST_TIMEOUT "$OPENROUTER_URL/models" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Could not fetch OpenRouter models"
        exit 1
    fi
    
    # Parse models from response
    local models=()
    
    # Simple fallback parsing for models
    log_info "Using simplified model list"
    
    # Just provide a curated list of known models
    models=(
        "anthropic/claude-3-sonnet-20240229	200000	0.000003	0.000015	Claude 3 Sonnet - Fast, balanced performance"
        "openai/gpt-3.5-turbo	16385	0.0000005	0.0000015	GPT-3.5 Turbo - Fast and affordable"
        "google/gemini-flash-1.5	1000000	0	0	Gemini Flash - Free tier available"
        "meta-llama/llama-3-8b-instruct:free	8192	0	0	Llama 3 8B - Free open model"
        "anthropic/claude-3-haiku-20240307	200000	0.00000025	0.00000125	Claude 3 Haiku - Very fast and cheap"
        "openai/gpt-4o-mini	128000	0.00000015	0.0000006	GPT-4o Mini - Smart and affordable"
        "mistralai/mistral-7b-instruct	32768	0.00000007	0.00000007	Mistral 7B - Efficient open model"
    )
    
    # Sort and display models
    if [ ${#models[@]} -eq 0 ]; then
        log_error "No models found"
        return 1
    fi
    
    # Sort models
    local sorted_models=()
    if [ "$sort_key" == "price" ]; then
        IFS=$'\n' sorted_models=($(printf '%s\n' "${models[@]}" | sort -t$'	' -k3 -g | head -n "$num"))
    elif [ "$sort_key" == "context" ]; then
        IFS=$'\n' sorted_models=($(printf '%s\n' "${models[@]}" | sort -t$'	' -k2 -rn | head -n "$num"))
    else
        IFS=$'\n' sorted_models=($(printf '%s\n' "${models[@]}" | sort -t$'	' -k3 -rg | head -n "$num"))
    fi
    
    # Display models
    printf '%s\n' "${sorted_models[@]}" | column -t -s $'	'
}

get_free_models() {
    local sort_key=$1
    
    local response=$(curl -s -m $REQUEST_TIMEOUT "$OPENROUTER_URL/models" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Could not fetch OpenRouter models"
        return 1
    fi
    
    # Return known free models
    echo "google/gemini-flash-1.5"
    echo "meta-llama/llama-3-8b-instruct:free"
    echo "microsoft/phi-3-mini-128k-instruct:free"
    echo "huggingfaceh4/zephyr-7b-beta:free"
    echo "nousresearch/nous-capybara-7b:free"
}

fetch_ollama_models() {
    log_info "Fetching Ollama models..."
    
    local response=$(curl -s -m $REQUEST_TIMEOUT "$OLLAMA_URL/tags" 2>/dev/null)
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to Ollama at $OLLAMA_URL"
        return
    fi
    
    # Parse Ollama models from response
    local models_array=$(parse_json_array "$response" "models")
    
    if [[ -z "$models_array" ]]; then
        # Try alternative parsing
        echo "$response" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//' | while read -r model_name; do
            echo "$model_name"
        done
    else
        # Parse each model
        echo "$response" | grep -o '{[^}]*"name"[^}]*}' | while read -r model; do
            local name=$(parse_json_value "$model" "name")
            local size=$(parse_json_value "$model" "size")
            local modified=$(parse_json_value "$model" "modified")
            printf "%s\t%s\t%s\n" "$name" "${size:-}" "${modified:-}"
        done | column -t
    fi
}

# ─── Processing Functions ─────────────────────────────────────────────────────

build_fix_prompt() {
    local base_prompt="$1"
    local fix_only=$2
    local target_file="$3"
    
    if [ $fix_only -eq 0 ]; then
        echo "$base_prompt"
    elif [ -n "$target_file" ]; then
        echo "Fix the TODOs in the file '$target_file' from the codebase below. Only return the complete fixed version of that file, nothing else. Do not include any explanations, headers, or markdown formatting: "
    else
        echo "Fix the TODOs in the code below. If this is a flattened codebase, identify the file that has TODOs and only return the complete fixed version of that file. Do not include any explanations, headers, or markdown formatting: "
    fi
}

process_with_openrouter() {
    local api_key="$1"
    local model="$2"
    local prompt="$3"
    local input_text="$4"
    local fix_only=$5
    local target_file="$6"
    
    local full_prompt=$(build_fix_prompt "$prompt" $fix_only "$target_file")
    full_prompt="${full_prompt}${input_text}"
    
    log_debug "Using model: $model"
    
    # Build JSON payload
    local escaped_prompt=$(escape_json_string "$full_prompt")
    local payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}], "temperature": 0.7}' \
        "$model" "$escaped_prompt")
    
    local response=$(curl -s -m $REQUEST_TIMEOUT \
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
        local error_msg=$(parse_json_value "$response" "message")
        if [[ -z "$error_msg" ]]; then
            error_msg=$(echo "$response" | grep -o '"error"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//')
        fi
        log_error "API error: ${error_msg:-Unknown error}"
        return 1
    fi
    
    # Extract content from choices array
    local content=""
    # Try to extract content from the first choice
    local choices_section=$(echo "$response" | grep -o '"choices"[[:space:]]*:[[:space:]]*\[[^]]*\]' | sed 's/^[^\[]*\[//')
    if [[ -n "$choices_section" ]]; then
        # Extract first message content
        local first_choice=$(echo "$choices_section" | sed 's/},.*$/}/')
        local message_section=$(echo "$first_choice" | grep -o '"message"[[:space:]]*:[[:space:]]*{[^}]*}')
        content=$(echo "$message_section" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//')
        # Unescape JSON string
        content=$(echo "$content" | sed 's/\\n/\n/g' | sed 's/\\t/\t/g' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g')
    fi
    
    if [ -z "$content" ]; then
        log_error "Empty response from API"
        return 1
    fi
    
    if [ $fix_only -eq 1 ]; then
        extract_fixed_file "$content"
    else
        echo "$content"
    fi
}

process_with_ollama() {
    local model="$1"
    local prompt="$2"
    local input_text="$3"
    local fix_only=$4
    local target_file="$5"
    
    local full_prompt=$(build_fix_prompt "$prompt" $fix_only "$target_file")
    full_prompt="${full_prompt}${input_text}"
    
    # Build JSON payload
    local escaped_prompt=$(escape_json_string "$full_prompt")
    local payload=$(printf '{"model": "%s", "messages": [{"role": "user", "content": "%s"}]}' \
        "$model" "$escaped_prompt")
    
    local response=$(curl -s -m $REQUEST_TIMEOUT \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$OLLAMA_URL/chat" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log_error "Cannot connect to Ollama at $OLLAMA_URL"
        exit 1
    fi
    
    # Extract content from Ollama response
    local content=""
    local message_section=$(echo "$response" | grep -o '"message"[[:space:]]*:[[:space:]]*{[^}]*}')
    if [[ -n "$message_section" ]]; then
        content=$(echo "$message_section" | grep -o '"content"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:"//' | sed 's/"$//')
        # Unescape JSON string
        content=$(echo "$content" | sed 's/\\n/\n/g' | sed 's/\\t/\t/g' | sed 's/\\"/"/g' | sed 's/\\\\/\\/g')
    fi
    
    if [ $fix_only -eq 1 ]; then
        extract_fixed_file "$content"
    else
        echo "$content"
    fi
}

# ─── TODO File Analysis ────────────────────────────────────────────────────────

analyze_codebase_for_todos() {
    local text="$1"
    echo "$text" | awk '
        /^# File: / {
            file = substr($0, 9)
            content = ""
        }
        /^# File: /,/^# File: |$/ {
            if (!/^# File: /) content = content "\n" $0
        }
        /TODO|FIXME/ {
            if (file) print file
            file = ""
        }
    ' | sort -u
}

# ─── Help Functions ────────────────────────────────────────────────────────────

show_help() {
    cat << EOF
AIFixer — Terminal-native AI coding assistant

Usage: aifixer [OPTIONS] [TEXT...]

Options:
  --version                Show version
  --help-examples          Show usage examples
  -v, --verbose           Enable verbose debugging output

Model Selection:
  --model MODEL           Model to use (default: $MODEL)
  --ollama-model MODEL    Use Ollama model instead
  --free                  Auto-select free/cheap model
  --max-fallbacks N       Number of fallback models (default: $MAX_FALLBACKS)

Model Listing:
  --list-models           List OpenRouter models
  --list-ollama-models    List Ollama models
  --num-models N          Number of models to show (default: $NUM_MODELS)
  --sort-by TYPE          Sort by: price, best, context (default: $SORT_BY)

Prompt & File Options:
  --prompt TEXT           Custom prompt (default: Fix TODOs...)
  --fix-file-only         Only output fixed code, no explanations
  --target-file FILE      Target specific file for fixes
  --list-todo-files       List files containing TODOs

Environment:
  OPENROUTER_API_KEY      Required for OpenRouter models

EOF
}

show_examples() {
    cat << EOF
Examples:
  # Fix TODOs in a file
  cat file.py | aifixer --model anthropic/claude-3-sonnet > fixed.py
  
  # Use a free model
  cat code.js | aifixer --free > output.js
  
  # List available models
  aifixer --list-models
  
  # Use local Ollama
  cat main.go | aifixer --ollama-model codellama > fixed.go
  
  # Custom prompt
  echo "Explain this:" | aifixer --prompt "Please explain: "

EOF
}

# ─── Main ──────────────────────────────────────────────────────────────────────

main() {
    local input_text=""
    local ollama_model=""
    local target_file=""
    local list_models=0
    local list_ollama=0
    local list_todos=0
    local help_examples=0
    local show_version=0
    local text_args=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
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
            -v|--verbose)
                VERBOSE=1
                DEBUG=1
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
            --free)
                FREE=1
                shift
                ;;
            --max-fallbacks)
                MAX_FALLBACKS="$2"
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
            --num-models)
                NUM_MODELS="$2"
                shift 2
                ;;
            --sort-by)
                SORT_BY="$2"
                shift 2
                ;;
            --prompt)
                PROMPT="$2"
                shift 2
                ;;
            --fix-file-only)
                FIX_FILE_ONLY=1
                shift
                ;;
            --target-file)
                target_file="$2"
                shift 2
                ;;
            --list-todo-files)
                list_todos=1
                shift
                ;;
            --)
                shift
                text_args+=("$@")
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                text_args+=("$1")
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
        fetch_openrouter_models $NUM_MODELS "$SORT_BY"
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
    if [ ${#text_args[@]} -gt 0 ]; then
        input_text="${text_args[*]}"
    elif [ ! -t 0 ]; then
        input_text=$(cat)
    else
        show_help
        exit 0
    fi
    
    # List TODO files if requested
    if [ $list_todos -eq 1 ]; then
        local todo_files=$(analyze_codebase_for_todos "$input_text")
        if [ -z "$todo_files" ]; then
            echo "No files with TODOs found"
        else
            echo "$todo_files"
        fi
        exit 0
    fi
    
    # Free model selection
    local fallback_models=()
    if [ $FREE -eq 1 ] && [ -z "$ollama_model" ]; then
        # Get free models in background
        {
            get_free_models "$SORT_BY" > /tmp/aifixer_free_models_$$
        } &
        local pid=$!
        spinner "Selecting free/cheap models..." $pid
        wait $pid
        local free_models=$(cat /tmp/aifixer_free_models_$$ 2>/dev/null)
        rm -f /tmp/aifixer_free_models_$$
        
        if [ -z "$free_models" ]; then
            log_error "No free/cheap models found"
            exit 1
        fi
        
        # Set primary model and fallbacks
        MODEL=$(echo "$free_models" | head -n1)
        mapfile -t fallback_models < <(echo "$free_models" | tail -n+2 | head -n$MAX_FALLBACKS)
        
        log_info "Selected model: $MODEL"
        if [ ${#fallback_models[@]} -gt 0 ]; then
            log_info "Fallback models: ${fallback_models[*]}"
        fi
    fi
    
    # Check API key
    local api_key="${OPENROUTER_API_KEY:-}"
    if [ -z "$ollama_model" ] && [ -z "$api_key" ]; then
        log_error "OPENROUTER_API_KEY not set; export it and retry."
        exit 1
    fi
    
    # Process the request
    local start_time=$(date +%s)
    local current_model="$MODEL"
    local result=""
    local success=0
    
    if [ -n "$ollama_model" ]; then
        current_model="$ollama_model"
        (
            result=$(process_with_ollama "$current_model" "$PROMPT" "$input_text" $FIX_FILE_ONLY "$target_file")
            echo "$result" > /tmp/aifixer_result_$$
        ) &
        spinner "Processing via Ollama ($current_model)..." $!
        result=$(cat /tmp/aifixer_result_$$ 2>/dev/null)
        rm -f /tmp/aifixer_result_$$
        success=1
    else
        # Try primary model first
        (
            result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text" $FIX_FILE_ONLY "$target_file" 2>&1)
            echo "$?" > /tmp/aifixer_status_$$
            echo "$result" > /tmp/aifixer_result_$$
        ) &
        spinner "Processing via OpenRouter ($current_model)..." $!
        
        local status=$(cat /tmp/aifixer_status_$$ 2>/dev/null || echo "1")
        result=$(cat /tmp/aifixer_result_$$ 2>/dev/null)
        rm -f /tmp/aifixer_status_$$ /tmp/aifixer_result_$$
        
        if [ "$status" -eq 0 ]; then
            success=1
        elif [ ${#fallback_models[@]} -gt 0 ]; then
            log_warning "Error with model $current_model - Trying fallback models..."
            
            # Try fallback models
            for model in "${fallback_models[@]}"; do
                current_model="$model"
                log_info "Trying fallback model: $current_model"
                
                (
                    result=$(process_with_openrouter "$api_key" "$current_model" "$PROMPT" "$input_text" $FIX_FILE_ONLY "$target_file" 2>&1)
                    echo "$?" > /tmp/aifixer_status_$$
                    echo "$result" > /tmp/aifixer_result_$$
                ) &
                spinner "Processing via OpenRouter ($current_model)..." $!
                
                status=$(cat /tmp/aifixer_status_$$ 2>/dev/null || echo "1")
                result=$(cat /tmp/aifixer_result_$$ 2>/dev/null)
                rm -f /tmp/aifixer_status_$$ /tmp/aifixer_result_$$
                
                if [ "$status" -eq 0 ]; then
                    log_info "✓ Fallback model $current_model succeeded"
                    success=1
                    break
                else
                    log_warning "Fallback model $current_model failed"
                fi
            done
        fi
    fi
    
    if [ $success -eq 0 ]; then
        log_error "All models failed"
        exit 1
    fi
    
    # Show completion message
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    if [ -t 2 ]; then
        log_info "Completed in ${elapsed}s with $current_model ✓"
    fi
    
    # Output result
    echo "$result"
}

# Run main function
main "$@"
