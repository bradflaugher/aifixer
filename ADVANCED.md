# AIFixer: Advanced Usage Guide

This document contains detailed information on advanced usage patterns, configuration options, and techniques for maximizing AIFixer's potential in your development workflow.

## Table of Contents

- [Configuration in Depth](#configuration-in-depth)
  - [API Keys and Environment Variables](#api-keys-and-environment-variables)
  - [Configuration File](#configuration-file)
  - [Model Selection Strategy](#model-selection-strategy)
- [Custom Prompts](#custom-prompts)
  - [Prompt Engineering Techniques](#prompt-engineering-techniques)
  - [Language-Specific Prompts](#language-specific-prompts)
  - [Task-Specific Prompts](#task-specific-prompts)
- [Workflow Integration](#workflow-integration)
  - [Git Hooks](#git-hooks)
  - [CI/CD Integration](#cicd-integration)
  - [Editor Integration](#editor-integration)
- [Codebase Analysis](#codebase-analysis)
  - [Processing Large Codebases](#processing-large-codebases)
  - [Extract-Transform-Load Patterns](#extract-transform-load-patterns)
  - [Multi-file Fixes](#multi-file-fixes)
- [Advanced Model Usage](#advanced-model-usage)
  - [OpenRouter API Details](#openrouter-api-details)
  - [Ollama Configuration](#ollama-configuration)
  - [Fine-tuning Suggestions](#fine-tuning-suggestions)
- [Extending AIFixer](#extending-aifixer)
  - [Custom Handlers](#custom-handlers)
  - [Plugin System](#plugin-system)
- [Performance Optimization](#performance-optimization)
  - [Reducing API Costs](#reducing-api-costs)
  - [Caching Strategies](#caching-strategies)
  - [Benchmarking Different Models](#benchmarking-different-models)
- [Troubleshooting](#troubleshooting)
  - [Common Errors](#common-errors)
  - [Debugging Techniques](#debugging-techniques)
  - [Logs and Diagnostics](#logs-and-diagnostics)

## Configuration in Depth

### API Keys and Environment Variables

AIFixer supports multiple environment variables for configuration:

```bash
# Required for OpenRouter API access
export OPENROUTER_API_KEY=your_api_key

# Optional: Set default model
export AIFIXER_DEFAULT_MODEL=anthropic/claude-3-sonnet-20240229

# Optional: Set Ollama endpoint (if not using default)
export OLLAMA_HOST=http://localhost:11434

# Optional: Enable detailed logging
export AIFIXER_DEBUG=1

# Optional: Set timeout for API requests (in seconds)
export AIFIXER_TIMEOUT=60

# Optional: Set custom prompt template directory
export AIFIXER_PROMPT_DIR=~/.config/aifixer/prompts
```

You can set these in your shell configuration files (`.bashrc`, `.zshrc`, etc.) for persistent configuration.

### Configuration File

AIFixer also supports a configuration file at `~/.config/aifixer/config.json`:

```json
{
  "api_key": "your_openrouter_api_key",
  "default_model": "anthropic/claude-3-sonnet-20240229",
  "ollama_host": "http://localhost:11434",
  "debug": false,
  "timeout": 60,
  "prompt_directory": "~/.config/aifixer/prompts",
  "cache_directory": "~/.cache/aifixer",
  "max_cache_size_mb": 100,
  "default_prompt_template": "Fix TODOs and improve code quality in this file: "
}
```

Environment variables take precedence over the configuration file.

### Model Selection Strategy

AIFixer employs a sophisticated model selection strategy:

1. **Explicit model selection** (`--model` or `--ollama-model` flags)
2. **Auto-selection based on task complexity** (when using `--auto-model`)
3. **Budget-aware selection** (when using `--free` or `--budget=X`)

For auto-selection, AIFixer analyzes:
- File size and complexity
- Number of TODOs and their complexity
- Programming language
- Expected token usage

## Custom Prompts

### Prompt Engineering Techniques

Effective prompts follow these patterns:

1. **Be specific about the task**:
   ```
   "Implement the data validation function based on the TODO comments, ensuring null checks and type validation"
   ```

2. **Provide context**:
   ```
   "This code uses the Express.js framework with MongoDB. Fix the TODO items related to authentication middleware"
   ```

3. **Set constraints**:
   ```
   "Optimize this algorithm while maintaining O(n) time complexity and minimizing memory usage"
   ```

4. **Request explanations**:
   ```
   "Fix the bugs in this function and explain your reasoning for each change"
   ```

### Language-Specific Prompts

AIFixer has optimized prompts for different programming languages:

**Python:**
```bash
cat python_file.py | aifixer --prompt "Refactor this Python code to follow PEP 8 standards and use more Pythonic constructs: " > refactored.py
```

**JavaScript:**
```bash
cat js_file.js | aifixer --prompt "Modernize this JavaScript code to use ES6+ features and follow current best practices: " > modern.js
```

**Java:**
```bash
cat java_file.java | aifixer --prompt "Refactor this Java code to follow clean code principles and use modern Java features: " > clean.java
```

### Task-Specific Prompts

**Security Hardening:**
```bash
cat api_endpoints.js | aifixer --prompt "Identify and fix security vulnerabilities including injection risks, missing authentication, and improper error handling: " > secure_api.js
```

**Performance Optimization:**
```bash
cat slow_function.py | aifixer --prompt "Optimize this function for performance by improving algorithmic efficiency, reducing memory usage, and eliminating redundant operations: " > optimized.py
```

**Documentation Generation:**
```bash
cat code.cpp | aifixer --prompt "Add comprehensive documentation including function descriptions, parameter details, return values, and usage examples in the appropriate format for C++: " > documented.cpp
```

## Workflow Integration

### Git Hooks

Create a pre-commit hook to automatically fix TODOs:

```bash
#!/bin/bash
# .git/hooks/pre-commit
set -e

# Get staged files
FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(js|py|java|rb|go|rs|ts)$')

for FILE in $FILES; do
  # Skip if file is empty or doesn't exist
  [ -s "$FILE" ] || continue
  
  # Check if file contains TODOs
  if grep -q "TODO" "$FILE"; then
    echo "Fixing TODOs in $FILE"
    # Create a temporary file
    TEMP=$(mktemp)
    # Fix TODOs
    cat "$FILE" | aifixer --prompt "Fix TODOs in this file: " > "$TEMP"
    # Replace original file
    mv "$TEMP" "$FILE"
    # Re-stage the file
    git add "$FILE"
  fi
done
```

Make the hook executable:
```bash
chmod +x .git/hooks/pre-commit
```

### CI/CD Integration

**GitHub Actions Example:**

```yaml
name: AIFixer Code Improvement

on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - '**.py'
      - '**.js'
      - '**.ts'

jobs:
  aifixer:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'
      
      - name: Install AIFixer
        run: |
          pip install requests
          curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py -o /usr/local/bin/aifixer
          chmod +x /usr/local/bin/aifixer
      
      - name: Find and fix TODOs
        env:
          OPENROUTER_API_KEY: ${{ secrets.OPENROUTER_API_KEY }}
        run: |
          git diff --name-only ${{ github.event.pull_request.base.sha }} ${{ github.sha }} | grep -E '\.(py|js|ts)$' | while read file; do
            if grep -q "TODO" "$file"; then
              echo "Fixing TODOs in $file"
              cat "$file" | aifixer > "$file.fixed"
              mv "$file.fixed" "$file"
            fi
          done
      
      - name: Commit changes
        uses: stefanzweifel/git-auto-commit-action@v4
        with:
          commit_message: "AI: Fix TODOs and improve code"
          branch: ${{ github.head_ref }}
```

### Editor Integration

**VS Code Task:**

Create a `.vscode/tasks.json` file:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "AIFixer: Fix current file",
      "type": "shell",
      "command": "cat ${file} | aifixer > ${file}.fixed && mv ${file}.fixed ${file}",
      "problemMatcher": [],
      "presentation": {
        "reveal": "silent",
        "panel": "shared"
      }
    },
    {
      "label": "AIFixer: Show diff for current file",
      "type": "shell",
      "command": "diff -u ${file} <(cat ${file} | aifixer) | delta",
      "problemMatcher": [],
      "presentation": {
        "reveal": "always",
        "panel": "shared"
      }
    }
  ]
}
```

**Vim Integration:**

Add to your `.vimrc`:

```vim
" AIFixer integration
function! AIFixerFix()
  let temp_file = tempname()
  execute "!cat " . expand("%") . " | aifixer > " . temp_file
  execute "!mv " . temp_file . " " . expand("%")
  edit!
endfunction

function! AIFixerDiff()
  execute "!diff -u " . expand("%") . " <(cat " . expand("%") . " | aifixer) | delta"
endfunction

command! AIFixerFix call AIFixerFix()
command! AIFixerDiff call AIFixerDiff()
```

## Codebase Analysis

### Processing Large Codebases

For large codebases, use the codebase-to-text tool:

```bash
# Install dependency
pip install codebase-to-text

# Convert entire codebase to text with intelligent filtering
codebase-to-text --input "~/projects/my_project" \
                 --output "/tmp/codebase.txt" \
                 --ignore "node_modules,dist,build,*.min.js" \
                 --include "*.js,*.py,*.java" \
                 --max-file-size 100000 \
                 --output_type "txt"

# Use the flattened codebase as context
cat /tmp/codebase.txt | aifixer --prompt "Given this codebase context, implement the feature described in the TODO comments in src/components/UserProfile.js. Only return the fixed UserProfile.js file: " > fixed_profile.js
```

### Extract-Transform-Load Patterns

For systematic code transformation across a codebase:

```bash
#!/bin/bash
# transform_codebase.sh
CODEBASE_DIR="$1"
TARGET_DIR="$2"
PROMPT="$3"

# Create output directory
mkdir -p "$TARGET_DIR"

# Find all relevant files
find "$CODEBASE_DIR" -type f -name "*.js" | while read file; do
  # Get relative path
  rel_path=${file#"$CODEBASE_DIR/"}
  # Create output directory structure
  output_dir="$TARGET_DIR/$(dirname "$rel_path")"
  mkdir -p "$output_dir"
  # Transform file
  echo "Processing $rel_path..."
  cat "$file" | aifixer --prompt "$PROMPT" > "$TARGET_DIR/$rel_path"
done
```

Usage:
```bash
./transform_codebase.sh ./src ./transformed "Convert this React class component to a functional component with hooks: "
```

### Multi-file Fixes

When changes span multiple files:

```bash
# Generate a plan first
find ./src -name "*.js" | xargs cat | aifixer --prompt "Analyze this code and create a refactoring plan to convert the authentication system from JWT to OAuth2. List all files that need changes and describe the required modifications for each: " > refactoring_plan.md

# Execute the plan file by file
cat refactoring_plan.md ./src/auth/authService.js | aifixer --prompt "Using the refactoring plan, modify authService.js to implement OAuth2 authentication: " > ./src/auth/authService.js.new
mv ./src/auth/authService.js.new ./src/auth/authService.js
```

## Advanced Model Usage

### OpenRouter API Details

OpenRouter provides access to various AI models through a unified API. AIFixer leverages this to offer model flexibility:

```bash
# List all available models
aifixer --list-models

# Use specific model with temperature setting
cat complex_code.py | aifixer --model anthropic/claude-3-opus-20240229 --temperature 0.7 > enhanced_code.py

# Set maximum tokens for response
cat outline.py | aifixer --model meta/llama-3-70b-instruct --max-tokens 4000 > implemented_code.py
```

Advanced OpenRouter parameters:

```bash
# Set context window size
cat large_file.py | aifixer --model anthropic/claude-3-sonnet-20240229 --context-window 100000 > fixed_file.py

# Control response format
cat api.js | aifixer --model openai/gpt-4-turbo --response-format json > api_docs.json
```

### Ollama Configuration

For local model usage with Ollama:

```bash
# Pull a specific model version
ollama pull codellama:13b

# Use a specific model with parameters
cat slow_algorithm.cpp | aifixer --ollama-model codellama:13b --ollama-params '{"temperature": 0.2, "top_p": 0.9, "repeat_penalty": 1.1}' > optimized_algorithm.cpp

# Customize Ollama endpoint
OLLAMA_HOST=http://my-ollama-server:11434 aifixer --ollama-model mistral < input.py > output.py
```

Create model-specific Modelfiles for specialized tasks:

```
# ./models/codellama-python-specialist.modelfile
FROM codellama:13b
PARAMETER temperature 0.2
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.2
SYSTEM """
You are a Python code improvement specialist. Focus on:
1. Following PEP 8 style guidelines
2. Using Pythonic idioms
3. Optimizing for readability and performance
4. Implementing robust error handling
"""
```

Then build and use the custom model:

```bash
ollama create python-specialist -f ./models/codellama-python-specialist.modelfile
cat python_script.py | aifixer --ollama-model python-specialist > improved_script.py
```

### Fine-tuning Suggestions

While AIFixer doesn't directly support fine-tuning, you can create custom specialized models:

1. Create a dataset of before/after code examples for your specific domain
2. Fine-tune a model using OpenAI's API or other services
3. Host the fine-tuned model and integrate with AIFixer

## Extending AIFixer

### Custom Handlers

AIFixer supports custom handlers through a plugin system:

```python
# ~/.config/aifixer/plugins/my_handler.py
from aifixer.plugin import register_handler

@register_handler("custom-format")
def handle_custom_format(code, options):
    """Process code in a custom format"""
    # Your custom processing logic here
    return processed_code

# Usage:
# cat special_file.xyz | aifixer --handler custom-format > processed_file.xyz
```

### Plugin System

Create plugins for special use cases:

```python
# ~/.config/aifixer/plugins/java_refactor.py
from aifixer.plugin import register_plugin

@register_plugin("java-refactor")
class JavaRefactorPlugin:
    """Plugin for advanced Java refactoring"""
    
    def __init__(self, options):
        self.options = options
    
    def preprocess(self, code):
        """Prepare code before sending to AI"""
        # Add imports, context, etc.
        return enhanced_code
    
    def postprocess(self, result):
        """Process AI result before returning"""
        # Format, validate, etc.
        return processed_result

# Usage:
# cat JavaClass.java | aifixer --plugin java-refactor --plugin-options '{"modernize": true}' > ModernJavaClass.java
```

## Performance Optimization

### Reducing API Costs

Strategies to minimize token usage and API costs:

1. **Code Preprocessing**:
   ```bash
   # Strip comments before sending to AI (except TODOs)
   cat large_file.py | grep -v "^[[:space:]]*#" | grep -v "^[[:space:]]*\/\/" | aifixer > fixed_file.py
   ```

2. **Use Free/Cheap Models for Simple Tasks**:
   ```bash
   # Let AIFixer choose the most economical model
   cat simple_fix.py | aifixer --free > fixed_simple.py
   ```

3. **Implement Caching**:
   ```bash
   # Enable result caching
   cat frequently_fixed.js | aifixer --cache > fixed_frequently.js
   ```

### Caching Strategies

AIFixer supports multiple caching strategies:

```bash
# Enable simple file-based caching
cat code.py | aifixer --cache > fixed_code.py

# Set cache timeout (in hours)
cat code.py | aifixer --cache --cache-ttl 48 > fixed_code.py

# Use a specific cache directory
cat code.py | aifixer --cache --cache-dir ~/.cache/my-aifixer-cache > fixed_code.py

# Clear cache
aifixer --clear-cache
```

### Benchmarking Different Models

Compare models for speed, quality, and cost:

```bash
#!/bin/bash
# benchmark.sh
TESTFILE="$1"

echo "Benchmarking models on $TESTFILE"
echo "=================================="

models=("anthropic/claude-3-sonnet-20240229" "openai/gpt-3.5-turbo" "meta/llama-3-8b-instruct")
ollama_models=("codellama" "mistral")

for model in "${models[@]}"; do
  echo -n "Testing $model: "
  time cat "$TESTFILE" | aifixer --model "$model" > /dev/null
done

for model in "${ollama_models[@]}"; do
  echo -n "Testing ollama model $model: "
  time cat "$TESTFILE" | aifixer --ollama-model "$model" > /dev/null
done
```

Usage:
```bash
./benchmark.sh example_code.py
```

## Troubleshooting

### Common Errors

**API Key Issues:**
```
Error: OPENROUTER_API_KEY environment variable not set

Solution:
export OPENROUTER_API_KEY=your_api_key
```

**Ollama Connection Issues:**
```
Error: Failed to connect to Ollama at http://localhost:11434

Solutions:
1. Check if Ollama is running: ps aux | grep ollama
2. Start Ollama: ollama serve
3. Check firewall settings
```

**Model Not Found:**
```
Error: Model 'custom-model' not found

Solutions:
1. Check available models: aifixer --list-models
2. For Ollama models: ollama list
3. Pull the model: ollama pull codellama
```

### Debugging Techniques

Enable verbose logging:

```bash
AIFIXER_DEBUG=1 cat file.py | aifixer > fixed.py
```

Inspect API requests and responses:

```bash
AIFIXER_DEBUG=1 AIFIXER_LOG_REQUESTS=1 cat file.py | aifixer > fixed.py 2> debug.log
```

### Logs and Diagnostics

AIFixer creates logs in `~/.cache/aifixer/logs`:

```bash
# View recent logs
cat ~/.cache/aifixer/logs/aifixer-$(date +%Y-%m-%d).log

# Monitor logs in real-time
tail -f ~/.cache/aifixer/logs/aifixer-$(date +%Y-%m-%d).log

# Search logs for errors
grep -i error ~/.cache/aifixer/logs/aifixer-*.log
```

Generate a diagnostic report:

```bash
aifixer --diagnostics > aifixer-diagnostics.txt
```

---

For more examples, community-contributed configurations, and the latest best practices, visit the [AIFixer GitHub repository](https://github.com/bradflaugher/aifixer).

Questions, suggestions, or need help? Open an issue on GitHub or join our community discussion.
