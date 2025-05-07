# AIFixer

<p align="center">
  <img src="./logo.svg" alt="AIFixer" width="600">
</p>

AIFixer is a lightweight, blazing-fast command-line tool that harnesses AI to enhance your coding workflow without ever leaving the terminal. Perfect for CLI enthusiasts, vim/emacs power users, and developers who prefer focused tools over bloated IDEs.

## Why AIFixer?

Most AI coding assistants are either embedded in heavy IDEs (like Cursor, Copilot, or CodeGPT) or require context switching to web interfaces (Claude, ChatGPT). AIFixer brings AI coding superpowers directly to your terminal workflow:

- **Terminal-native** - No browser tabs, no GUI apps, just pure CLI efficiency
- **Blazing fast** - Get AI-powered code fixes in seconds
- **Cost-effective** - While Claude Code is powerful, it can strain your budget. AIFixer lets you choose between powerful cloud models for complex tasks or economical/free alternatives for simpler fixes. By controlling exactly what context you send, you minimize token usage and maximize value—perfect for developers mindful of API costs.​​​​​​​​​​​​​​​​
- **Universal** - Works with any programming language or framework
- **Composable** - Follows the Unix philosophy: do one thing well and work with other tools
- **BYOM (Bring Your Own Model)** - Use ANY model from:
  - OpenRouter API (Claude, GPT, Llama, etc.)
  - Local Ollama models (run completely offline)
- **Minimal dependencies** - Just Python and requests
- **Maximum flexibility** - Custom prompts, file extraction, codebase analysis

## Installation

```bash
# Download, make executable, and install in one go
curl -s https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py | sudo tee /usr/local/bin/aifixer >/dev/null && sudo chmod +x /usr/local/bin/aifixer
```

## Configuration

### OpenRouter API

AIFixer uses the OpenRouter API by default. You'll need to set up your API key:

```bash
export OPENROUTER_API_KEY=your_api_key
```

For permanent configuration, add this line to your `~/.bashrc` or `~/.zshrc` file.

### Ollama Setup (Optional)

To use local Ollama models:

1. Install Ollama from [ollama.ai](https://ollama.ai)
2. Pull the models you want to use:
   ```bash
   ollama pull codellama
   ollama pull llama3
   ```
3. Make sure Ollama is running in the background before using AIFixer with the `--ollama-model` flag

## Basic Usage

### Fix TODOs (The Main Event)

```bash
# The classic: pipe a file with TODOs, get back fixed code
cat file_with_todos.py | aifixer > fixed_file.py

# Or use a redirect (same result)
aifixer < file_with_todos.py > fixed_file.py
```

### Choose Your Model

```bash
# Use a powerful cloud model
cat complex_feature.py | aifixer --model anthropic/claude-3-opus-20240229 > implemented_feature.py

# Go local & offline with Ollama
cat performance_bottleneck.js | aifixer --ollama-model codellama > optimized_code.js

# Let AIFixer pick the most economical model automatically 
cat simple_script.py | aifixer --free > improved_script.py
```

### One-liners That Save Time

```bash
# Edit a file in-place
aifixer < slow_function.rb | sponge slow_function.rb  # requires moreutils

# See a diff of the changes
diff -u <(cat buggy_code.c) <(cat buggy_code.c | aifixer) | delta  # delta for pretty diffs

# Fix all your TODOs and immediately commit (dangerous but awesome)
cat file_with_todos.py | aifixer > file_with_todos.py && git commit -am "Fix TODOs with AIFixer"
```

## Advanced Usage

### Processing an Entire Codebase

You can use AIFixer with codebase-to-text to analyze and fix an entire codebase but only return a specific file:

```bash
# Install codebase-to-text if needed
pip install codebase-to-text

# Convert codebase to text, fix it with AIFixer, and extract only the file with TODOs
codebase-to-text --input "~/projects/my_project" --output - --output_type "txt" | \
aifixer --fix-file-only > fixed_file.py
```

### Examining a Codebase to Fix a Single File

If you want to give the AI context from your entire codebase but only edit one file:

```bash
# Create a flattened view of the codebase
codebase-to-text --input "~/projects/my_project" --output "/tmp/flattened_codebase.txt" --output_type "txt"

# Use the flattened codebase as context to fix a specific file
cat /tmp/flattened_codebase.txt | aifixer --prompt "Using the codebase context provided, fix the TODOs in the file 'src/utils/formatter.js' and only return that file: " > fixed_formatter.js
```

### Custom Prompts

Define custom prompts for specific tasks:

```bash
# Fix bugs in a file
cat buggy_file.py | aifixer --prompt "Find and fix all bugs in this code: " > fixed_file.py

# Add documentation to functions
cat poorly_documented.py | aifixer --prompt "Add comprehensive docstrings to all functions in this code: " > documented_file.py

# Optimize a slow algorithm
cat slow_algorithm.py | aifixer --prompt "Optimize this algorithm for better performance and explain your changes: " > optimized_algorithm.py
```

### List Available Models

OpenRouter models:

```bash
aifixer --list-models
```

Local Ollama models:

```bash
aifixer --list-ollama-models
```

## Best Practices

1. **Use git before running AIFixer** - This allows you to compare changes and revert if needed
2. **Review AI changes** - Always review the generated code before committing
3. **Use specific prompts** - More specific prompts yield better results
4. **Try different models** - Different models have different strengths
5. **Provide context** - For complex fixes, include related files or documentation

## Advanced Examples

### Improving Error Handling

```bash
cat app.js | aifixer --prompt "Improve error handling in this code by adding try/catch blocks and proper error logging: " > improved_app.js
```

### Implementing a Feature Based on Comments

```bash
cat feature_outline.py | aifixer --prompt "Implement the feature described in the comments and TODOs: " > implemented_feature.py
```

### Refactoring Code

```bash
cat legacy_code.java | aifixer --prompt "Refactor this code to use modern Java features and improve readability: " > refactored_code.java
```

### Migrating Between Frameworks

```bash
cat react_component.jsx | aifixer --prompt "Convert this React class component to a functional component with hooks: " > functional_component.jsx
```

## Troubleshooting

### API Key Issues

If you see "Error: OPENROUTER_API_KEY environment variable not set":

```bash
export OPENROUTER_API_KEY=your_api_key
```

### Ollama Connection Issues

If you see "Error: Failed to connect to Ollama":

1. Check if Ollama is running: `ps aux | grep ollama`
2. Start Ollama if it's not running: `ollama serve`
3. Try again with `--list-ollama-models` to verify connection

### Code Output Issues

If the AI generates code that doesn't compile or work as expected:

1. Try a different model: `--model anthropic/claude-3-opus-20240229`
2. Be more specific in your prompt
3. Break down complex tasks into smaller steps

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Why Not Use...?

### VS Code + Copilot/Cursor/CodeGPT?
Great tools, but they're **700MB+ apps** that take over your workflow. AIFixer is a **single file** that integrates with your existing terminal tools.

### ChatGPT/Claude Web Interface?
Copying and pasting code between browser and terminal breaks flow. AIFixer keeps you in your terminal, where your focus belongs.

### Anthropic's Claude Code or GitHub's Copilot CLI?
These are awesome more comprehensive tools, but AIFixer:
- Is smaller and more focused
- Gives you model flexibility (use ANY model)
- Follows Unix philosophy (do one thing well)
- Works right now, with your code, your terminal, your way

## License

This project is licensed under the GPLv3 License - see the LICENSE file for details.

## Acknowledgments

- OpenRouter for providing API access to various models
- Ollama for local model inference
- Anthropic's Claude and other LLM providers
- All the command-line warriors who inspired this tool

---

<p align="center"><i>For developers who know that AI tools should augment your workflow, not replace it.</i></p>
