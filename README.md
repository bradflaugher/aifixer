# 🔧 AIFixer: POSIX-compliant terminal-based coding tool with OpenRouter and ollama support

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
  <strong>🤖 AI-powered code improvements directly in your terminal</strong>
  <br>
  <em>Transform TODOs into working code • Fix bugs • Add error handling • Refactor with confidence</em>
</p>

---

## 📥 Installation

Works on any Unix-like system (Linux, macOS, BSD) or Windows with WSL.

### Quick Install

```sh
curl -sL https://raw.githubusercontent.com/bradflaugher/aifixer/main/install.sh | sh
```

<details>
<summary><strong>Manual Install</strong></summary>

```sh
# Download the script
wget https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.sh
chmod +x aifixer.sh

# Set your API key
export OPENROUTER_API_KEY="your-key-here"
```

</details>

## 🤯 Let AI explain a code to you 

```sh
# Help!
cat messy_script.sh | aifixer "please explain to me what this does"
```


## ✨ Let AI write a new file from scratch

```sh
# Generate code
aifixer --prompt "write me an interactive bash script to harden my ubuntu install" > hadening_script.sh
```

## 📚 Give aifixer an existing file to fix 

```sh
# Fix a file
cat broken_code.py | aifixer > fixed_code.py
```

> **📝 Note about Default Behavior**
> 
> The default prompt for AIFixer is designed to fix TODOs and improve code quality. For best results when using the default prompt, ensure your input file contains TODO comments that describe what needs to be implemented or fixed.
> 
> **Example workflow:**
> 1. Add TODO comments to your code describing what needs to be done
> 2. Pipe the file to AIFixer: `cat broken_code.py | aifixer > fixed_code.py`
> 3. AIFixer will implement the TODOs and improve the overall code quality
> 
> See the examples below for input and output demonstrations.

<details>
<summary>example <code>broken_code.py</code> (click to expand)</summary>

```python
def process_user_data(user_id):
    # TODO: Validate user_id format
    # TODO: Add logging
    # TODO: Handle database connection errors
    
    conn = get_db_connection()
    return conn.query(f"SELECT * FROM users WHERE id = {user_id}")
```

</details>

<details>
<summary>example <code>fixed_code.py</code> (click to expand)</summary>

```python
import logging
import re
from contextlib import contextmanager

logger = logging.getLogger(__name__)

def process_user_data(user_id):
    # Validate user_id format
    if not isinstance(user_id, (int, str)):
        raise ValueError("user_id must be an integer or string")
    
    if isinstance(user_id, str) and not re.match(r'^\d+$', user_id):
        raise ValueError("user_id string must contain only digits")
    
    logger.info(f"Processing data for user_id: {user_id}")
    
    # Handle database connection errors
    try:
        with get_db_connection() as conn:
            # Use parameterized query to prevent SQL injection
            result = conn.query("SELECT * FROM users WHERE id = ?", (user_id,))
            logger.debug(f"Retrieved {len(result)} rows for user_id: {user_id}")
            return result
    except DatabaseConnectionError as e:
        logger.error(f"Database connection failed: {e}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error processing user_id {user_id}: {e}")
        raise
```

</details>


## 📋 What is AIFixer?

AIFixer is a command-line tool that uses AI to automatically fix, improve, and complete your code. It's designed as a simple Unix filter: pipe in code, get improved code out.

**✨ Key features:**
- **🎯 Portable**: POSIX-compliant shell script that runs on any Unix-like system
- **📦 No dependencies**: Works out of the box without package managers or runtime environments
- **🔌 Flexible**: Supports multiple AI providers (OpenRouter, Ollama for local models)
- **🐧 Unix philosophy**: Designed to work with pipes, scripts, and existing workflows

## 🎯 Common Use Cases

<details>
<summary><strong>🛡️ Adding Error Handling</strong></summary>

```sh
# Add comprehensive error handling
cat api_client.js | aifixer --prompt "Add proper error handling and retry logic" > robust_api_client.js
```
</details>

<details>
<summary><strong>♻️ Refactoring Code</strong></summary>

```sh
# Refactor for better performance
cat slow_algorithm.py | aifixer --prompt "Optimize this algorithm for better time complexity" > optimized_algorithm.py

# Improve code structure
cat monolithic_function.js | aifixer --prompt "Break this into smaller, testable functions" > refactored.js
```
</details>

<details>
<summary><strong>🚀 Advanced Usage</strong></summary>

**Model Selection:**
```sh
# List available models
aifixer --list-models

# Use a specific model
cat code.py | aifixer --model anthropic/claude-4-opus > fixed.py
```

**Local AI with Ollama:**
```sh
# Install and use a local model
ollama pull codellama
cat code.py | aifixer --ollama-model codellama > fixed.py
```

</details>

<details>
<summary><strong>⚙️ How It Works</strong></summary>

AIFixer follows the Unix philosophy of doing one thing well:

1. **📥 Read** code from stdin
2. **🔍 Analyze** the code using AI to identify issues and TODOs
3. **⚡ Generate** improved code
4. **📤 Output** the result to stdout

This simple design makes it easy to integrate into existing workflows, CI/CD pipelines, and shell scripts.

</details>

## 📊 Comparison with Alternatives

| Feature | AIFixer | Claude Code | Aider | Cursor |
|---------|---------|-------------|-------|----------------|
| **🖥️ Interface** | 🚀 CLI (pipe-based) | 🤖 CLI (interactive) | 🤖 CLI (interactive) | 🔌 IDE |
| **📦 Dependencies** | ✨ None (shell script) ✅ | 📦 Node.js | 🐍 Python | 💻 IDE |
| **🌐 Offline Support** | 🏠 Yes (via Ollama) ✅ | ☁️ No ❌ | ☁️ No ❌ | ☁️ No ❌ |
| **💰 Price Model** | 💳 Pay-per-use (via OpenRouter) | 💳 Pay-per-use or 🔄 Subscription | 💳 Pay-per-use | 🔄 Subscription |
| **💾 System Requirements** | 🥔 Runs on a potato ✅ | 🖥️ Modern system | 🖥️ Modern system | 🖥️ Modern System |
| **🎯 Model Selection** | 🔥 Choose any model per task ✅ | 🔒 Limited to Claude models | 🔒 Pre-configured models | 🔒 Pre-configured models |
| **🧠 Model Flexibility** | 💪 Use GPT-4o, Claude Opus, Gemini Pro, etc. | 🤖 Claude Haiku/Sonnet/Opus | 🤖 GPT-4/3.5 mainly | 🤖 Limited provider support |

### Why Model Choice Matters

> NOTE: See a full list of supported models at [openrouter.ai/models](https://openrouter.ai/models?order=top-weekly)

With AIFixer, you can choose the right model for each task:
- **🚀 Complex refactoring?** → Use the latest frontier models as soon as they're released
- **⚡ Quick fixes?** → Use distilled, optimized and quantized models if you like
- **💰 Budget conscious?** → Mix and match models based on task complexity
- **🔒 Privacy concerns?** → Use local models via Ollama, or an open source model from OpenRouter

Other tools often lock you into using their default model (sometimes a lighter version to save costs), but AIFixer lets you leverage the full power of frontier models when you need it most.
