# AIFixer 🛠️

<p align="center">
  <img src="./logo.svg" alt="AIFixer" width="600">
  <br>
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

<details>
<summary>🔧 Error handling and robustness</summary>

**Input:**
```javascript
function fetchUserData(userId) {
    const response = fetch(`/api/users/${userId}`);
    const data = response.json();
    return data.user;
}
```

**Output:**
```javascript
async function fetchUserData(userId) {
    try {
        if (!userId) {
            throw new Error('User ID is required');
        }
        
        const response = await fetch(`/api/users/${userId}`);
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (!data.user) {
            throw new Error('User data not found in response');
        }
        
        return data.user;
    } catch (error) {
        console.error('Failed to fetch user data:', error);
        throw error;
    }
}
```
</details>

## 🔧 Installation Options

### Automatic Installation (Recommended)
```sh
curl -sL https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
```

### Manual Installation
```sh
# Clone the repo
git clone https://github.com/bradflaugher/aifixer.git
cd aifixer

# Run installer with options
sh install.sh --help
```

### Installation Flags
| Flag | Description |
|------|-------------|
| `--prefix DIR` | Install to custom directory |
| `--api-key KEY` | Set API key non-interactively |
| `--skip-deps` | Skip checks for basic Unix utilities |
| `--skip-api-key` | Don't modify shell configs |

### Minimal Setup
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

### CI/CD Integration
```sh
# Check if fixes are needed (non-zero exit if changes made)
if cat src/*.py | aifixer --check-only; then
    echo "Code is clean!"
else
    echo "Fixes available - run aifixer to apply"
fi
```

## 🎛️ Configuration

### API Keys
Set your OpenRouter API key (installer does this automatically):
```sh
export OPENROUTER_API_KEY="your-key-here"
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
- **⚡ Fast** - Streams output, handles large files efficiently  
- **🪶 Ultra Portable** - POSIX-compliant shell script with zero dependencies beyond standard Unix tools
- **💰 Cost Aware** - Use free models or bring your own key
- **🌐 Language Agnostic** - Works with any programming language
- **🔗 Composable** - Perfect for pipes, scripts, and CI/CD
- **🛡️ Safe** - Preview changes before applying

## 📖 Documentation

- [Advanced Usage Guide](ADVANCED.md) - Power user features and tricks
- [Testing Guide](TESTING.md) - Integration tests and validation
- [Contributing](CONTRIBUTING.md) - How to contribute to the project

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