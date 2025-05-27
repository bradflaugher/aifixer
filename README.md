# AIFixer 🛠️ - Fix Bugs in Seconds, Not Hours

<p align="center">
  <img src="./logo.svg" alt="AIFixer" width="600">
  <br>
  <a href="https://github.com/bradflaugher/aifixer/actions"><img src="https://img.shields.io/github/actions/workflow/status/bradflaugher/aifixer/ci.yml?branch=main&style=flat-square" alt="Build Status"></a>
  <a href="https://github.com/bradflaugher/aifixer/stargazers"><img src="https://img.shields.io/github/stars/bradflaugher/aifixer?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/bradflaugher/aifixer/network/members"><img src="https://img.shields.io/github/forks/bradflaugher/aifixer?style=flat-square" alt="Forks"></a>
  <a href="https://github.com/bradflaugher/aifixer/issues"><img src="https://img.shields.io/github/issues/bradflaugher/aifixer?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/bradflaugher/aifixer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bradflaugher/aifixer?style=flat-square" alt="License"></a>
</p>

<p align="center">
  <strong>AI-powered code fixes and improvements, right in your terminal</strong>
  <br>
  <em>Turn TODOs into working code • Fix bugs instantly • Refactor with confidence</em>
</p>

<p align="center">
  <strong>🔥 Join 1,000+ developers fixing code 10x faster</strong>
</p>

---

## 🎬 See It In Action

<p align="center">
  <em>⚡ TODO to working code in 5 seconds:</em>
</p>

```bash
# Before: Broken code with TODOs
$ cat calculator.py
def calculate_total(items):
    # TODO: handle empty list
    # TODO: validate inputs
    return sum(items)

# After: Fixed and production-ready
$ cat calculator.py | aifixer --fix-file-only > calculator_fixed.py
$ cat calculator_fixed.py
def calculate_total(items):
    if not items:
        return 0
    
    total = 0
    for item in items:
        if isinstance(item, (int, float)):
            total += item
        else:
            raise ValueError(f"Invalid item type: {type(item)}")
    
    return total
```

---

## 🚀 What is AIFixer?

AIFixer is a terminal-native tool that uses AI to automatically fix, improve, and complete your code. Pipe in broken code, get working code back out. It's that simple.

**Built for maximum portability:** POSIX-compliant shell script that runs anywhere - from your local machine to ancient production servers, restricted environments, or that random Unix box you SSH'd into. No installations, no package managers, no version conflicts.

**Perfect for:**
- Implementing TODO comments
- Fixing syntax errors and bugs  
- Adding error handling and validation
- Refactoring messy code
- Adding documentation and comments

## ⚡ Quick Start

**Install in one command:**
```sh
curl -sL https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
```

**Fix your first file:**
```sh
cat broken_code.py | aifixer > fixed_code.py
```

That's it! The installer asks for your API key once and puts `aifixer` on your PATH. No dependencies to install - it's a POSIX-compliant shell script that runs on any Unix-like system.

## 🎯 See It in Action

**Before** → **After**

<details>
<summary>🐛 Bug fixes and TODO implementation</summary>

**Input:**
```python
def calculate_total(items):
    # TODO: Implement validation for empty list
    total = 0
    for item in items:
        # TODO: Handle non-numeric items
        total += item
    # TODO: Add support for discount calculation
    return total
```

**Output:**
```python
def calculate_total(items):
    """Calculate total with validation and discount support."""
    # Validate empty list
    if not items:
        return 0.0

    total = 0.0
    for item in items:
        # Handle non-numeric items gracefully
        try:
            total += float(item)
        except (TypeError, ValueError):
            print(f"Warning: Skipping non-numeric item: {item}")
            continue

    # Apply discount for orders over $100
    discount_rate = 0.1 if total > 100 else 0.0
    return total * (1 - discount_rate)
```
</details>


## 🔧 Installation Options

### Automatic Installation (Recommended)
```sh
curl -sL https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
```

### Manual Setup
Just want the script? Download `aifixer.sh`, make it executable, and add your API key:
```sh
chmod +x aifixer.sh
export OPENROUTER_API_KEY="your-key-here"
```

## 💡 Usage Examples

### Basic Usage
```sh
# Fix a single file
cat buggy.py | aifixer > fixed.py

# Preview changes before applying
diff -u original.js <(cat original.js | aifixer)

# Fix and commit in one go
cat feature.py | aifixer > feature.py && git commit -am "AI fixes applied"
```

### Advanced Usage
```sh
# Use specific AI model
aifixer --model anthropic/claude-3-opus-20240229 < complex.py > improved.py

# Custom instructions
aifixer --prompt "Add comprehensive error handling" < server.js > server_safe.js

# Local/offline with Ollama
aifixer --ollama-model codellama < script.sh > script_fixed.sh

# Code only, no explanations
aifixer --code-only < messy.c > clean.c
```

### Output Modes

**Default Mode (with explanations):**
```sh
# Get the full AI response including code and explanations
cat code.py | aifixer
# Output includes: fixed code + explanation of changes + reasoning
```

**Fix-File-Only Mode (clean code):**
```sh
# Get only the fixed code without any explanations
cat code.py | aifixer --fix-file-only
# Output: Just the fixed code, perfect for piping to files
```

### Model Selection
```sh
# List available models
aifixer --list-models

# Use free models when possible
aifixer --free-models-first

# Set default model
export AIFIXER_DEFAULT_MODEL="anthropic/claude-3-haiku-20240307"
```

### Local AI with Ollama
```sh
# Install Ollama and pull a model
ollama pull codellama

# Use local model
aifixer --ollama-model codellama < code.py > fixed.py
```

## 🌟 Why AIFixer?

- **🖥️ Terminal Native** - No browser context switching
- **⚡ Fast** - Handles large files efficiently  
- **🪶 Ultra Portable** - POSIX-compliant shell script with zero dependencies beyond standard Unix tools
- **💰 Cost Aware** - Bring your own OpenRouter API key
- **🌐 Language Agnostic** - Works with any programming language
- **🔗 Composable** - Perfect for pipes, scripts, and CI/CD
- **🛡️ Safe** - Preview changes before applying

### 🏆 AIFixer vs Alternatives

| Feature | AIFixer | Claude Code | Aider | GitHub Copilot | ChatGPT |
|---------|---------|-------------|-------|----------------|----------|
| **Price** | Pay per token | Pay per token | Pay per token | $19/month | $20/month |
| **Terminal Native** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ IDE only | ❌ Browser |
| **Zero Dependencies** | ✅ Yes | ❌ Node.js | ❌ Python | ❌ VS Code | ❌ Browser |
| **Bulk File Processing** | ✅ Yes | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Works Offline** | ✅ Yes (Ollama) | ❌ No | ❌ No | ❌ No | ❌ No |
| **Simple Piping** | ✅ Yes | ❌ Interactive | ❌ Interactive | ❌ N/A | ❌ Copy/paste |
| **CI/CD Ready** | ✅ Yes | ❌ No | ⚠️ Complex | ❌ No | ❌ No |
| **Runs on a Potato** | ✅ Any Unix box | ❌ Modern only | ❌ Python 3.8+ | ❌ Azure's servers | ❌ OpenAI's GPUs |

## 📖 Advanced Usage

### Custom Prompts

```sh
# Add error handling
cat app.js | aifixer --prompt "Add error handling to this code: " > robust_app.js

# Add documentation
cat undocumented.py | aifixer --prompt "Add docstrings to all functions: " > documented.py

# Optimize performance
cat slow_code.py | aifixer --prompt "Optimize this code for better performance: " > fast_code.py
```

### Viewing Changes

```sh
# Save the fixed version and compare
cat original.py | aifixer > fixed.py
diff -u original.py fixed.py

# Or use the fix-file-only mode for cleaner diffs
cat original.py | aifixer --fix-file-only > fixed.py
diff -u original.py fixed.py
```

### In-place Editing

```sh
# Using a temporary file
cat file.js | aifixer --fix-file-only > file.js.tmp && mv file.js.tmp file.js

# Process multiple TODO files
for file in *.py; do
  if grep -q "TODO" "$file"; then
    cat "$file" | aifixer --fix-file-only > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done
```

### Working with Multiple Files

```sh
# Fix all Python files with TODOs
for file in $(find . -name "*.py" -exec grep -l "TODO" {} \;); do
  echo "Processing $file..."
  cat "$file" | aifixer --fix-file-only > "$file.tmp" && mv "$file.tmp" "$file"
done
```

### Git Integration

```sh
# Fix TODOs before committing
git diff --name-only | grep '\.py$' | while read file; do
  if grep -q "TODO" "$file"; then
    cat "$file" | aifixer --fix-file-only > "$file.tmp" && mv "$file.tmp" "$file"
  fi
done
```


### Model Selection Guide

| Task Complexity | Suggested Model | Example Command |
|-----------------|----------------|-----------------|
| Simple fixes | Use economical models | `cat simple.py \| aifixer --free` |
| Standard TODOs | Default model | `cat standard.js \| aifixer` |
| Complex algorithms | More powerful models | `cat complex.py \| aifixer --model anthropic/claude-3-opus-20240229` |
| Local/offline work | Ollama models | `cat code.py \| aifixer --ollama-model codellama` |

## 🔧 Troubleshooting

### Common Issues

**API Key Issues:**
```sh
# Error: OPENROUTER_API_KEY environment variable not set
export OPENROUTER_API_KEY=your_api_key
```

**Ollama Connection Issues:**
```sh
# Check if Ollama is running
ps aux | grep ollama

# Start Ollama if needed
ollama serve

# Verify models are installed
ollama list
```



## 🌍 Join the Community

<p align="center">
  <a href="https://twitter.com/intent/tweet?text=Just%20discovered%20AIFixer%20-%20it%20fixed%20my%20TODOs%20in%20seconds!%20%F0%9F%9A%80%20Check%20it%20out%3A%20https%3A%2F%2Fgithub.com%2Fbradflaugher%2Faifixer%20%23AIFixer%20%23DevTools"><strong>🐦 Share on Twitter</strong></a> • 
  <a href="https://github.com/bradflaugher/aifixer/stargazers"><strong>⭐ Star on GitHub</strong></a> • 
  <a href="https://github.com/bradflaugher/aifixer/discussions"><strong>💬 Join Discussions</strong></a>
</p>

## 🤝 Contributing

We love contributions! Whether it's bug reports, feature requests, or code improvements:

1. **⭐ Star this repo** if you find it useful
2. **🐛 Report bugs** via GitHub issues  
3. **💡 Submit feature requests** with use cases
4. **🔧 Submit PRs** for improvements

## 📄 License

This project is licensed under the GPL-3.0 License - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <strong>Happy coding! 🚀</strong>
</p>
