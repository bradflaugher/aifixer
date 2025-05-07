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
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py | sudo tee /usr/local/bin/aifixer >/dev/null && sudo chmod +x /usr/local/bin/aifixer

# Set your API key
export OPENROUTER_API_KEY=your_api_key

# Fix a file with TODOs
cat file_with_todos.py | aifixer > fixed_file.py
```

## 🔥 Why Developers Love AIFixer

Most AI coding assistants pull you away from the command line into IDEs or browser interfaces. **AIFixer brings AI directly to your terminal** – where programmers are most productive.

- **✅ 100% Terminal-native** - No browser tabs or GUI apps to slow you down
- **✅ Lightning-fast** - AI code fixes in seconds, right where you need them
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

AIFixer requires Python and the `requests` library:

```bash
# Debian/Ubuntu
sudo apt install python3-requests

# Fedora/RHEL/CentOS
sudo dnf install python3-requests

# Arch Linux
sudo pacman -S python-requests

# OpenSUSE
sudo zypper install python3-requests

# Other Linux/Mac with pip
pip install requests   # or pip3 install requests on some systems
```

### Install AIFixer

**Quick install (Linux/Mac):**
```bash
# One-line install (requires sudo)
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py | sudo tee /usr/local/bin/aifixer >/dev/null && sudo chmod +x /usr/local/bin/aifixer
```

**Alternative without sudo:**
```bash
# For Homebrew users or if ~/.local/bin is in your PATH
mkdir -p ~/.local/bin
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py -o ~/.local/bin/aifixer
chmod +x ~/.local/bin/aifixer
```

**Windows users:**
See [WINDOWS.md](./WINDOWS.md) for Windows installation instructions.


## 🔑 Configuration

### API Key Setup

**Set your OpenRouter API key (required for cloud models):**

```bash
# Linux/Mac
export OPENROUTER_API_KEY=your_api_key

# Windows
$env:OPENROUTER_API_KEY = "your_api_key"
```

For permanent configuration:
- **Linux/Mac**: Add to `~/.bashrc` or `~/.zshrc`
- **Windows**: Add to PowerShell profile or system environment variables

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
```

### List Available Models

```bash
# List cloud models
aifixer --list-models

# List local Ollama models
aifixer --list-ollama-models
```

## 🧙‍♂️ Advanced Usage

### Custom Prompts for Specific Tasks

```bash
# Add documentation to functions
cat poorly_documented.py | aifixer --prompt "Add comprehensive docstrings to all functions: " > documented_file.py

# Optimize a slow algorithm
cat slow_algorithm.py | aifixer --prompt "Optimize this algorithm for better performance: " > optimized_algorithm.py
```

### Working with Entire Codebases

```bash
# Install codebase-to-text if needed
pip install codebase-to-text

# Convert codebase to text, fix it, extract only one file
codebase-to-text --input "~/projects/my_project" --output - --output_type "txt" | \
aifixer --fix-file-only > fixed_file.py
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
- See the [Wiki](https://github.com/bradflaugher/aifixer/wiki) for additional resources

## ⚖️ License

This project is licensed under the GPLv3 License - see the LICENSE file for details.

---

<p align="center"><i>For developers who know that AI tools should augment your workflow, not replace it.</i></p>