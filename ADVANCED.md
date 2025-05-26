# AIFixer Advanced Usage Guide

This guide contains practical examples and techniques for getting the most out of AIFixer in your daily development workflow.

## Table of Contents

- [Advanced Usage Examples](#advanced-usage-examples)
- [Custom Prompts Library](#custom-prompts-library)
- [Working with Codebases](#working-with-codebases)
- [Workflow Integration](#workflow-integration)
- [Model Selection Guide](#model-selection-guide)
- [Troubleshooting](#troubleshooting)

## Advanced Usage Examples

### Output Modes and Piping

AIFixer supports two output modes to suit different workflows:

**Default Mode (with explanations):**
```bash
# Get the full AI response including code and explanations
cat code.py | aifixer
# Output includes: fixed code + explanation of changes + reasoning
```

**Fix-File-Only Mode (clean code):**
```bash
# Get only the fixed code without any explanations
cat code.py | aifixer --fix-file-only
# Output: Just the fixed code, perfect for piping to files
```

**When to use each mode:**
```bash
# Use default mode when you want to understand the changes:
cat complex_algorithm.py | aifixer | less

# Use --fix-file-only when piping to files or automated workflows:
cat buggy.py | aifixer --fix-file-only > fixed.py

# In CI/CD pipelines:
cat src/main.js | aifixer --fix-file-only > src/main.js.fixed
mv src/main.js.fixed src/main.js

# For batch processing:
find . -name "*.py" -exec sh -c 'cat {} | aifixer --fix-file-only > {}.tmp && mv {}.tmp {}' \;
```

### Fix TODOs by Language

**Python:**
```bash
# Fix TODOs in a Python file
cat script.py | aifixer --prompt "Implement the TODOs in this Python file following PEP 8 style: " > fixed_script.py
```

**JavaScript:**
```bash
# Fix TODOs in a JavaScript file
cat app.js | aifixer --prompt "Implement the TODOs in this JavaScript file using modern ES6+ syntax: " > fixed_app.js
```

**Java:**
```bash
# Fix TODOs in a Java file
cat Service.java | aifixer --prompt "Implement the TODOs in this Java file following clean code principles: " > fixed_Service.java
```

### Viewing Changes

```bash
# See a diff of the changes (using diff)
diff -u original_file.py <(cat original_file.py | aifixer)

# See a diff with colors (using delta)
diff -u original_file.py <(cat original_file.py | aifixer) | delta

# See a diff with context (3 lines before and after)
diff -u -c3 original_file.py <(cat original_file.py | aifixer)
```

### In-place Editing

```bash
# Using sponge from moreutils
cat file.py | aifixer --fix-file-only | sponge file.py

# Using a temporary file
cat file.js | aifixer --fix-file-only > file.js.tmp && mv file.js.tmp file.js

# Edit multiple files at once
for file in $(grep -l "TODO" *.py); do
  cat $file | aifixer --fix-file-only | sponge $file
done
```

### Combining with Other Tools

```bash
# Fix only files that contain "FIXME" comments
grep -l "FIXME" *.js | xargs -I{} sh -c 'cat {} | aifixer > {}.fixed && mv {}.fixed {}'

# Process only files that have changed in git
git diff --name-only | grep '\.py$' | xargs -I{} sh -c 'cat {} | aifixer > {}.fixed && mv {}.fixed {}'

# Fix TODOs and run tests immediately
cat file.py | aifixer > file.py && pytest file_test.py
```

## Custom Prompts Library

Here's a collection of effective custom prompts for different scenarios:

### Code Quality Improvement

```bash
# Improve error handling
cat app.js | aifixer --prompt "Add robust error handling to all functions in this code: " > robust_app.js

# Improve performance
cat slow_algorithm.py | aifixer --prompt "Optimize this algorithm for better performance while maintaining the same functionality: " > fast_algorithm.py

# Add logging
cat service.rb | aifixer --prompt "Add appropriate logging statements throughout this code for better debugging: " > logged_service.rb
```

### Documentation Tasks

```bash
# Add docstrings/comments
cat undocumented.py | aifixer --prompt "Add comprehensive docstrings to all functions following Google-style Python docstring format: " > documented.py

# Generate README
cat main.py | aifixer --prompt "Based on this main file, generate a comprehensive README.md for this project: " > README.md

# Create usage examples
cat library.js | aifixer --prompt "Create usage examples for each public function in this library: " > examples.js
```

### Refactoring Tasks

```bash
# Convert class components to functional components in React
cat ClassComponent.jsx | aifixer --prompt "Convert this React class component to a functional component using hooks: " > FunctionalComponent.jsx

# Split large functions
cat large_function.py | aifixer --prompt "Refactor this large function into smaller, more maintainable functions: " > refactored.py

# Apply design patterns
cat implementation.java | aifixer --prompt "Refactor this code to use the Factory design pattern: " > factory_implementation.java
```

## Working with Codebases

### Processing an Entire Codebase

```bash
# Install codebase-to-text
pip install codebase-to-text

# Process a small project
codebase-to-text --input "./my_project" --output "/tmp/codebase.txt" --output_type "txt"
cat /tmp/codebase.txt | aifixer --prompt "Fix all TODOs across this codebase and return the complete fixed code: " > /tmp/fixed_codebase.txt

# Process a specific file in a larger codebase context
codebase-to-text --input "./large_project" --output "/tmp/context.txt" --output_type "txt"
cat /tmp/context.txt | aifixer --prompt "Using this codebase as context, implement the TODOs in src/components/UserProfile.js and only return that file: " > fixed_UserProfile.js
```

### Processing Specific File Types

```bash
# Process all Python files
find . -name "*.py" | xargs -I{} sh -c 'cat {} | aifixer > {}.fixed && mv {}.fixed {}'

# Process only files containing TODOs
grep -l "TODO" $(find . -name "*.js") | xargs -I{} sh -c 'cat {} | aifixer > {}.fixed && mv {}.fixed {}'

# Process files modified in the last day
find . -name "*.py" -mtime -1 | xargs -I{} sh -c 'cat {} | aifixer > {}.fixed && mv {}.fixed {}'
```

### Batch Processing with Custom Prompts

```bash
#!/bin/bash
# batch_process.sh

PROJECT_DIR="$1"
PROMPT="$2"

echo "Processing all TODO items in $PROJECT_DIR with prompt: $PROMPT"

# Find all files with TODOs
TODO_FILES=$(grep -l "TODO" $(find "$PROJECT_DIR" -type f -name "*.py"))

# Process each file
for file in $TODO_FILES; do
  echo "Processing $file..."
  cat "$file" | aifixer --prompt "$PROMPT" > "$file.fixed"
  mv "$file.fixed" "$file"
done

echo "All files processed successfully!"
```

Usage:
```bash
./batch_process.sh ./src "Fix TODOs and add proper error handling: "
```

## Workflow Integration

### Git Pre-commit Hook

Create a `.git/hooks/pre-commit` file:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Get all staged files
STAGED_FILES=$(git diff --staged --name-only)

# Filter for relevant file types
CODE_FILES=$(echo "$STAGED_FILES" | grep -E '\.(py|js|java|rb|go|ts)$')

# Exit if no relevant files are staged
if [ -z "$CODE_FILES" ]; then
  exit 0
fi

# Check for TODOs in staged files
TODO_FILES=$(grep -l "TODO" $CODE_FILES)

if [ -n "$TODO_FILES" ]; then
  echo "Found TODOs in the following staged files:"
  echo "$TODO_FILES"
  
  read -p "Would you like AIFixer to implement these TODOs? (y/n) " -n 1 -r
  echo
  
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    for file in $TODO_FILES; do
      echo "Fixing TODOs in $file..."
      cat "$file" | aifixer > "$file.fixed"
      mv "$file.fixed" "$file"
      git add "$file"
    done
    echo "All TODOs fixed and staged!"
  else
    echo "Continuing with commit without fixing TODOs."
  fi
fi

exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

### Editor Integration

**VS Code Task Configuration** (`.vscode/tasks.json`):

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "AIFixer: Fix TODOs in current file",
      "type": "shell",
      "command": "cat ${file} | aifixer > ${file}.fixed && mv ${file}.fixed ${file}",
      "presentation": {
        "reveal": "silent",
        "panel": "shared"
      },
      "problemMatcher": []
    },
    {
      "label": "AIFixer: Show diff for current file",
      "type": "shell",
      "command": "diff -u ${file} <(cat ${file} | aifixer) | delta",
      "presentation": {
        "reveal": "always",
        "panel": "shared"
      },
      "problemMatcher": []
    }
  ]
}
```

**Vim Configuration** (add to `.vimrc`):

```vim
" AIFixer integration
command! AIFixerFix :!cat % | aifixer > %.fixed && mv %.fixed %
command! AIFixerDiff :!diff -u % <(cat % | aifixer) | delta
```

## Model Selection Guide

### When to Use Different Models

| Task Complexity | Suggested Model | Example Command |
|-----------------|----------------|-----------------|
| Simple fixes (typos, format) | Use economical models | `cat simple.py \| aifixer --free` |
| Standard TODOs | Default model | `cat standard.js \| aifixer` |
| Complex algorithms | More powerful models | `cat complex_algo.py \| aifixer --model anthropic/claude-3-opus-20240229` |
| Local/offline work | Ollama models | `cat code.py \| aifixer --ollama-model codellama` |

### Model Comparison Matrix

Experiment with different models to find what works best for your specific needs:

```bash
#!/bin/bash
# model_comparison.sh
TEST_FILE="$1"

echo "Testing AIFixer with different models on $TEST_FILE"
echo "====================================================="

# Make a backup
cp "$TEST_FILE" "$TEST_FILE.bak"

# Test with different models
models=("anthropic/claude-3-sonnet-20240229" "openai/gpt-3.5-turbo" "anthropic/claude-3-opus-20240229")
for model in "${models[@]}"; do
  echo "Testing with $model..."
  cat "$TEST_FILE.bak" | aifixer --model "$model" > "$TEST_FILE.$model"
  echo "  Result saved to $TEST_FILE.$model"
done

# Test with Ollama if available
if command -v ollama &> /dev/null; then
  ollama_models=("codellama" "llama3")
  for model in "${ollama_models[@]}"; do
    echo "Testing with Ollama model $model..."
    cat "$TEST_FILE.bak" | aifixer --ollama-model "$model" > "$TEST_FILE.ollama-$model"
    echo "  Result saved to $TEST_FILE.ollama-$model"
  done
fi

echo "Done! Compare results with: diff -u $TEST_FILE.bak $TEST_FILE.[model]"
```

Usage:
```bash
./model_comparison.sh complex_function.py
```

## Troubleshooting

### Common Issues and Solutions

**API Key Issues:**
```
Error: OPENROUTER_API_KEY environment variable not set

Solution:
export OPENROUTER_API_KEY=your_api_key
```

**Ollama Connection Issues:**
```
Error: Failed to connect to Ollama

Solutions:
1. Check if Ollama is running: ps aux | grep ollama
2. Start Ollama if needed: ollama serve
3. Verify models are installed: ollama list
```

**Ollama Output Formatting:**
```
If Ollama output appears garbled or on separate lines:

This is fixed in AIFixer v1.3.0+. The tool now properly handles Ollama's
streaming responses and formats the output correctly.

Example usage with Ollama:
cat code.py | aifixer --ollama-model gemma3:1b
cat code.py | aifixer --ollama-model gemma3:1b --fix-file-only
```

**Python Requests Module Missing:**
```
Error: ModuleNotFoundError: No module named 'requests'

Solutions:
# For Debian/Ubuntu:
sudo apt install python3-requests

# For other systems:
pip install requests
```

### Debugging Tips

Enable verbose output:
```bash
# Set environment variable for debugging
AIFIXER_DEBUG=1 cat file.py | aifixer
```

Verify model availability:
```bash
# Check available models
aifixer --list-models
aifixer --list-ollama-models
```

Test with a minimal example:
```bash
# Create a simple test file
echo -e "def add(a, b):\n    # TODO: Implement this function\n    pass" > test.py
cat test.py | aifixer
```

For further troubleshooting, consult the [TESTING.md](./TESTING.md) file for integration test information and validation methods.

---

For more examples, community contributions, and the latest best practices, visit the [AIFixer GitHub repository](https://github.com/bradflaugher/aifixer).