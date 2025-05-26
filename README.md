# AIFixer 🛠️ - AI-powered code fixes in your terminal

<p align="center">
  <img src="./logo.svg" alt="AIFixer" width="600">
  <br>
  <a href="https://github.com/bradflaugher/aifixer/stargazers"><img src="https://img.shields.io/github/stars/bradflaugher/aifixer?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/bradflaugher/aifixer/network/members"><img src="https://img.shields.io/github/forks/bradflaugher/aifixer?style=flat-square" alt="Forks"></a>
  <a href="https://github.com/bradflaugher/aifixer/issues"><img src="https://img.shields.io/github/issues/bradflaugher/aifixer?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/bradflaugher/aifixer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/bradflaugher/aifixer?style=flat-square" alt="License"></a>
</p>

<p align="center"><strong>Harness AI to fix your code without ever leaving the terminal.</strong></p>

## ⚡ Get Started in 10 Seconds

```bash
# Install
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh | sudo tee /usr/local/bin/aifixer >/dev/null && sudo chmod +x /usr/local/bin/aifixer

# Set your API key
export OPENROUTER_API_KEY=your_api_key

# Fix a file with TODOs
cat file_with_todos.py | aifixer > fixed_file.py
```

## 🧪 Example: Before & After

### Before: File with TODOs

```python
def calculate_total(items):
    # TODO: Implement validation for empty list
    total = 0
    for item in items:
        # TODO: Handle non-numeric items
        total += item
    # TODO: Add support for discount calculation
    return total

def process_order(order_data):
    # TODO: Add error handling for missing fields
    items = order_data['items']
    total = calculate_total(items)
    # TODO: Implement tax calculation
    return {
        'order_id': order_data['id'],
        'total': total,
        # TODO: Add timestamp for order processing
    }
```

### After: Fixed with AIFixer

```python
def calculate_total(items):
    # Validate empty list
    if not items:
        return 0
        
    total = 0
    for item in items:
        # Handle non-numeric items
        try:
            total += float(item)
        except (TypeError, ValueError):
            continue
    
    # Support for discount calculation
    discount_rate = 0.1 if total > 100 else 0
    total = total * (1 - discount_rate)
    
    return total

def process_order(order_data):
    # Error handling for missing fields
    if not order_data or not isinstance(order_data, dict):
        raise ValueError("Invalid order data: must be a non-empty dictionary")
    
    if 'items' not in order_data:
        raise KeyError("Missing required field: 'items'")
    
    if 'id' not in order_data:
        raise KeyError("Missing required field: 'id'")
        
    items = order_data['items']
    total = calculate_total(items)
    
    # Implement tax calculation
    tax_rate = 0.08  # 8% tax rate
    tax_amount = total * tax_rate
    total_with_tax = total + tax_amount
    
    import datetime
    
    return {
        'order_id': order_data['id'],
        'total': total_with_tax,
        'tax': tax_amount,
        'processed_at': datetime.datetime.now().isoformat(),  # Add timestamp
    }
```

## 🔥 Why Developers Love AIFixer

Most AI coding assistants pull you away from the command line into IDEs or browser interfaces. **AIFixer brings AI directly to your terminal** – where programmers are most productive.

- **✅ 100% Terminal-native** - No browser tabs or GUI apps to slow you down
- **✅ Lightning-fast** - AI code fixes in seconds, right where you need them
- **✅ Minimal dependencies** - Just bash and curl – works everywhere
- **✅ Handles massive files** - Easily processes large codebases where other tools struggle or fail
- **✅ Cost-effective** - Use powerful cloud models or free alternatives – you control the budget
- **✅ Universal** - Works with any programming language or framework
- **✅ Composable** - Pipe in your code, pipe out fixed code – Unix philosophy at its best

## 🤯 See It In Action

```bash
# Show a diff of the changes AIFixer will make
diff -u <(cat buggy_code.c) <(cat buggy_code.c | aifixer) | delta

# Fix all TODOs and immediately commit (dangerous but awesome)
cat feature.py | aifixer > feature.py && git commit -am "Implement feature with AIFixer"

# Process specific code patterns with custom prompts
cat api.js | aifixer --prompt "Add input validation to all API endpoints: " > secure_api.js
```

## 🔧 Installation

### Prerequisites

AIFixer is written in bash and requires minimal dependencies:

- **bash** (v4.0+) - Usually pre-installed on Linux/Mac
- **curl** - For API requests
- **jq** (optional but recommended) - For better JSON parsing

```bash
# Debian/Ubuntu
sudo apt install curl jq

# Fedora/RHEL/CentOS
sudo dnf install curl jq

# Arch Linux
sudo pacman -S curl jq

# Mac (with Homebrew)
brew install curl jq

# OpenSUSE
sudo zypper install curl jq
```

### Install AIFixer

**Quick install (Linux/Mac):**
```bash
# One-line install (requires sudo)
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh | sudo tee /usr/local/bin/aifixer >/dev/null && sudo chmod +x /usr/local/bin/aifixer
```

**Alternative without sudo:**
```bash
# For Homebrew users or if ~/.local/bin is in your PATH
mkdir -p ~/.local/bin
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh -o ~/.local/bin/aifixer
chmod +x ~/.local/bin/aifixer
```

### Windows Installation

AIFixer can run on Windows using Git Bash, WSL, or Cygwin.

**Option 1: Git Bash (Recommended)**
1. Install [Git for Windows](https://git-scm.com/download/win) (includes Git Bash)
2. Open Git Bash
3. Run:
   ```bash
   # Download to your home directory
   curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh -o ~/aifixer
   chmod +x ~/aifixer
   
   # Add to PATH (add this to ~/.bashrc to make permanent)
   export PATH="$HOME:$PATH"
   ```

**Option 2: Windows Subsystem for Linux (WSL)**
1. Install WSL: `wsl --install` (in PowerShell as Administrator)
2. Open WSL terminal
3. Follow the Linux installation instructions above

**Option 3: Native Windows (PowerShell)**
```powershell
# Download the script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh" -OutFile "$env:USERPROFILE\aifixer.sh"

# You'll need a bash interpreter like Git Bash to run it
# Then run: bash ~/aifixer.sh
```

## 🔑 Configuration

### API Key Setup

**Set your OpenRouter API key (required for cloud models):**

```bash
# Linux/Mac
export OPENROUTER_API_KEY=your_api_key

# Windows (Git Bash)
export OPENROUTER_API_KEY=your_api_key

# Windows (PowerShell - if using WSL)
$env:OPENROUTER_API_KEY = "your_api_key"
```

For permanent configuration:
- **Linux/Mac/Git Bash**: Add to `~/.bashrc` or `~/.zshrc`
- **Windows PowerShell**: Add to PowerShell profile or system environment variables

### Ollama Setup (Optional for offline use)

1. Install Ollama from [ollama.ai](https://ollama.ai)
2. Pull models: `ollama pull codellama`
3. Start Ollama in background

## 💡 Models & Flexibility

### Choose Your Model

```bash
# Use a powerful cloud model for complex tasks
cat complex_feature.py | aifixer --model anthropic/claude-3-opus-20240229 > implemented_feature.py

# Go lightweight for simpler fixes
cat typo_fix.js | aifixer --model openai/gpt-3.5-turbo > fixed.js

# Use a free/local model with Ollama
cat performance_bottleneck.js | aifixer --ollama-model codellama > optimized_code.js

# Auto-select a free model
cat code.py | aifixer --free > fixed_code.py
```

### List Available Models

```bash
# List cloud models
aifixer --list-models

# List local Ollama models
aifixer --list-ollama-models

# Sort models by context length
aifixer --list-models --sort-by context

# Show only top 10 cheapest models
aifixer --list-models --num-models 10 --sort-by price
```

## 🧙‍♂️ Advanced Usage

### Custom Prompts for Specific Tasks

```bash
# Add documentation to functions
cat poorly_documented.py | aifixer --prompt "Add comprehensive docstrings to all functions: " > documented_file.py

# Optimize a slow algorithm
cat slow_algorithm.py | aifixer --prompt "Optimize this algorithm for better performance: " > optimized_algorithm.py

# Convert code to a different style
cat old_style.js | aifixer --prompt "Convert this to modern ES6+ syntax: " > modern_style.js
```

### Working with Entire Codebases

```bash
# Install codebase-to-text if needed
pip install codebase-to-text

# Convert codebase to text, fix it, extract only one file
codebase-to-text --input "~/projects/my_project" --output - --output_type "txt" | \
aifixer --fix-file-only > fixed_file.py

# List all files with TODOs in a codebase
codebase-to-text --input . --output - | aifixer --list-todo-files

# Fix a specific file from a codebase
codebase-to-text --input . --output - | \
aifixer --target-file "src/main.py" --fix-file-only > fixed_main.py
```

### Advanced Features

```bash
# Use fallback models if primary fails (great for free models)
cat code.py | aifixer --free --max-fallbacks 3 > output.py

# Enable verbose debugging
cat code.py | aifixer --verbose --model gpt-4 > output.py

# See help and examples
aifixer --help
aifixer --help-examples
```

## 📢 Spread the Word

If AIFixer saves you time:

- ⭐ Star the project on GitHub
- 🐦 Share on Twitter/X: [`Click to tweet about AIFixer`](https://twitter.com/intent/tweet?text=Just%20discovered%20AIFixer%3A%20AI-powered%20code%20fixes%20right%20in%20the%20terminal!%20No%20more%20copying%20%26%20pasting%20to%20ChatGPT%20or%20leaving%20my%20workflow.%20Check%20it%20out%3A%20https%3A//github.com/bradflaugher/aifixer)
- 👥 Show your colleagues
- 📝 Blog about your experience

## 📚 Documentation

- [ADVANCED.md](./ADVANCED.md) - Detailed usage, customization options, and advanced techniques
- [TESTING.md](./TESTING.md) - Information on integration tests and validation

## ⚖️ License

This project is licensed under the GPLv3 License - see the LICENSE file for details.

---

<p align="center"><i>For developers who know that AI tools should augment your workflow, not replace it.</i></p>