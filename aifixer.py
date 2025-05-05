#!/usr/bin/python3

import sys
import requests
import json
import argparse
import os
import re
import time
import platform
import shutil
from textwrap import dedent

VERSION = "1.1.0"

# ASCII art banner for the tool
ASCII_BANNER = r"""
    _    ___ _____ _                 
   / \  |_ _|  ___(_)_  _____ _ __ 
  / _ \  | || |_  | \ \/ / _ \ '__|
 / ___ \ | ||  _| | |>  <  __/ |   
/_/   \_\___|_|   |_/_/\_\___|_|   
                                    
 Your terminal-native AI coding assistant
--------------------------------------------
"""

def fetch_openrouter_models(num_models, auto_select, sort_key='price'):
    """Fetch available models from OpenRouter API"""
    url = 'https://openrouter.ai/api/v1/models'
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        models = response.json().get('data', [])

        # Filter out models without pricing information
        models = [model for model in models if model.get('pricing') and model.get('id') != 'openrouter/auto']

        # Allow sorting by different criteria
        sort_options = {
            'price': lambda x: (x['pricing'].get('prompt', float('inf')), -x['context_length']),
            'best': lambda x: (-float(x['pricing'].get('prompt', 0)), -x['context_length']),
            'context': lambda x: (-int(x['context_length']), float(x['pricing'].get('prompt', float('inf')))),
        }
        
        # Use the provided sort_key to sort the models
        models.sort(key=sort_options[sort_key])

        # Select the specified number of models
        selected_models = models[:num_models]

        if auto_select and len(selected_models) > 0:
            print(selected_models[0].get('id',''), end="")
            return

        # Define table headers
        headers = ['Model ID', 'Context Length', 'Prompt Cost', 'Completion Cost', 'Description']

        # Calculate column widths
        col_widths = [len(header) for header in headers]
        max_desc_length = 135  # Truncate description to this length

        for model in selected_models:
            col_widths[0] = max(col_widths[0], len(model.get('id', '')))
            col_widths[1] = max(col_widths[1], len(str(model.get('context_length', ''))))
            col_widths[2] = max(col_widths[2], len(str(model.get('pricing', {}).get('prompt', ''))))
            col_widths[3] = max(col_widths[3], len(str(model.get('pricing', {}).get('completion', ''))))

        # Print table header
        header_row = " | ".join(f"{header:<{col_widths[i]}}" for i, header in enumerate(headers[:-1])) + f" | {headers[-1]}"
        print(header_row)
        print("-" * len(header_row))

        # Print table rows
        for model in selected_models:
            description = model.get('description', '').replace('\n', ' ')
            if len(description) > max_desc_length:
                description = description[:max_desc_length] + "..."  # Truncate and add ellipsis

            row = [
                model.get('id', ''),
                str(model.get('context_length', '')),
                str(model.get('pricing', {}).get('prompt', '')),
                str(model.get('pricing', {}).get('completion', '')),
                description
            ]
            row_str = " | ".join(f"{row[i]:<{col_widths[i]}}" for i in range(len(row) - 1)) + f" | {row[-1]}"
            print(row_str)
    else:
        print(f"Failed to retrieve models. Status code: {response.status_code}")
        print(f"Response: {response.text}")

def fetch_ollama_models():
    """Fetch available models from local Ollama instance"""
    url = 'http://localhost:11434/api/tags'
    
    try:
        response = requests.get(url)
        
        if response.status_code == 200:
            models = response.json().get('models', [])
            
            # Define table headers
            headers = ['Model Name', 'Size', 'Modified Date', 'Family']
            
            # Calculate column widths
            col_widths = [len(header) for header in headers]
            
            for model in models:
                col_widths[0] = max(col_widths[0], len(model.get('name', '')))
                col_widths[1] = max(col_widths[1], len(format_size(model.get('size', 0))))
                col_widths[2] = max(col_widths[2], len(model.get('modified', '')))
                family = model.get('details', {}).get('family', '')
                col_widths[3] = max(col_widths[3], len(family))
            
            # Print table header
            header_row = " | ".join(f"{header:<{col_widths[i]}}" for i, header in enumerate(headers))
            print(header_row)
            print("-" * len(header_row))
            
            # Print table rows
            for model in models:
                family = model.get('details', {}).get('family', '')
                row = [
                    model.get('name', ''),
                    format_size(model.get('size', 0)),
                    model.get('modified', ''),
                    family
                ]
                row_str = " | ".join(f"{row[i]:<{col_widths[i]}}" for i in range(len(row)))
                print(row_str)
        else:
            print(f"Failed to retrieve Ollama models. Status code: {response.status_code}")
            print(f"Response: {response.text}")
    except requests.exceptions.ConnectionError:
        print("Failed to connect to Ollama. Is Ollama running on localhost:11434?")

def format_size(size_bytes):
    """Format bytes to human-readable form"""
    if size_bytes == 0:
        return "0B"
    size_names = ("B", "KB", "MB", "GB", "TB")
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024
        i += 1
    return f"{size_bytes:.2f} {size_names[i]}"

def get_input():
    """Get input from command line arguments or stdin"""
    # Check if we have any command line arguments (after the options)
    if len(sys.argv) > 1 and not sys.argv[-1].startswith('-'):
        return ' '.join(sys.argv[1:])
    # Otherwise, check if we have data from stdin
    elif not sys.stdin.isatty():
        return sys.stdin.read()
    else:
        return ""

def process_with_openrouter(api_key, model, prompt, input_text, fix_file_only=False, target_file=None):
    """Process input with OpenRouter API"""
    # Adjust prompt if we're only looking for one file
    if fix_file_only:
        if target_file:
            prompt = f"Fix the TODOs in the file '{target_file}' from the codebase below. Only return the complete fixed version of '{target_file}', nothing else. Do not include any explanations, headers, or markdown formatting: "
        else:
            prompt = "Fix the TODOs in the code below. If this is a flattened codebase, identify the file that has TODOs and only return the complete fixed version of that file. Do not include any explanations, headers, or markdown formatting: "
    
    url = "https://openrouter.ai/api/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json"
    }
    data = {
        "model": model,
        "messages": [
            {"role": "user", "content": prompt + input_text}
        ]
    }

    response = requests.post(url, headers=headers, data=json.dumps(data))

    if response.status_code == 200:
        output = response.json()["choices"][0]["message"]["content"]
        
        # Process output if we're in fix-file-only mode
        if fix_file_only:
            return extract_fixed_file(output)
        
        return output
    else:
        print(f"Error: Failed to retrieve response. Status code: {response.status_code}")
        print(f"Response: {response.text}")
        sys.exit(1)

def process_with_ollama(model, prompt, input_text, fix_file_only=False, target_file=None):
    """Process input with local Ollama API"""
    # Adjust prompt if we're only looking for one file
    if fix_file_only:
        if target_file:
            prompt = f"Fix the TODOs in the file '{target_file}' from the codebase below. Only return the complete fixed version of '{target_file}', nothing else. Do not include any explanations, headers, or markdown formatting: "
        else:
            prompt = "Fix the TODOs in the code below. If this is a flattened codebase, identify the file that has TODOs and only return the complete fixed version of that file. Do not include any explanations, headers, or markdown formatting: "
    
    url = "http://localhost:11434/api/chat"
    data = {
        "model": model,
        "messages": [
            {"role": "user", "content": prompt + input_text}
        ],
        "stream": False
    }

    try:
        response = requests.post(url, data=json.dumps(data))
        
        if response.status_code == 200:
            output = response.json()["message"]["content"]
            
            # Process output if we're in fix-file-only mode
            if fix_file_only:
                return extract_fixed_file(output)
            
            return output
        else:
            print(f"Error: Failed to retrieve response from Ollama. Status code: {response.status_code}")
            print(f"Response: {response.text}")
            sys.exit(1)
    except requests.exceptions.ConnectionError:
        print("Error: Failed to connect to Ollama. Is Ollama running on localhost:11434?")
        sys.exit(1)

def extract_fixed_file(output):
    """Extract the fixed file from AI output, removing markdown code blocks if present"""
    # Try to extract code from markdown code blocks
    code_block_pattern = r"```(?:\w+)?\s*([\s\S]+?)\s*```"
    code_blocks = re.findall(code_block_pattern, output)
    
    if code_blocks:
        # Return the largest code block (most likely the complete file)
        return max(code_blocks, key=len).strip()
    
    # If no code blocks, check for file path patterns and potential sections
    file_path_pattern = r"(?:```\s*(\S+)\s*```)|(?:Fixed version of `(.+?)`:)|(?:# (\S+))"
    file_paths = re.findall(file_path_pattern, output)
    
    if file_paths:
        # Flatten the tuple list and filter out empty strings
        found_paths = [path for paths in file_paths for path in paths if path]
        if found_paths:
            # Look for a code block that follows any file path mention
            for path in found_paths:
                path_followed_by_code = re.search(rf"{re.escape(path)}.*?```(?:\w+)?\s*([\s\S]+?)\s*```", output, re.DOTALL)
                if path_followed_by_code:
                    return path_followed_by_code.group(1).strip()
    
    # If all other patterns fail, treat the whole response as code
    # But first, let's try to remove any clear non-code parts
    
    # Remove potential headers
    output = re.sub(r'^#.*?\n', '', output)
    
    # Remove "Here's the fixed version:" type lines
    output = re.sub(r'^.*?(?:fixed|corrected|completed|implemented).*?\n', '', output, flags=re.IGNORECASE)
    
    # Remove markdown-style section headers
    output = re.sub(r'^#+\s+.*?\n', '', output, flags=re.MULTILINE)
    
    # If there are still explanations at the beginning, try to find where the code starts
    code_start_indicators = [
        r'^\s*(?:function|class|import|package|#include|using|public|private|def|const|let|var|module)',
        r'^\s*(?:<\?php|\<\!DOCTYPE|<html)'
    ]
    
    for indicator in code_start_indicators:
        match = re.search(indicator, output, re.MULTILINE)
        if match:
            start_pos = match.start()
            if start_pos > 0:
                output = output[start_pos:]
                break
    
    # Return the cleaned output
    return output.strip()

def analyze_codebase_for_todos(input_text):
    """Analyze a flattened codebase to identify files with TODOs"""
    # Pattern to identify file paths in flattened codebase
    file_pattern = r"# File: (.+)"
    files = re.findall(file_pattern, input_text)
    
    # Pattern to identify TODOs
    todo_pattern = r"(?i)TODO|FIXME"
    
    files_with_todos = []
    
    # Split the flattened codebase by file markers
    parts = re.split(file_pattern, input_text)
    
    # First element is before any file marker, skip it
    parts = parts[1:]
    
    # Process in pairs (filename, content)
    for i in range(0, len(parts), 2):
        if i+1 < len(parts):
            filename = parts[i]
            content = parts[i+1]
            
            if re.search(todo_pattern, content):
                files_with_todos.append(filename)
    
    return files_with_todos

def print_examples():
    """Print usage examples with colorized output"""
    c = get_term_colors()
    
    print(f"\n{c['bold']}AIFixer Usage Examples{c['reset']}\n")
    
    # Basic Examples
    print(f"{c['bold']}📝 Basic Usage{c['reset']}")
    print(f"  {c['green']}# Fix TODOs in a file{c['reset']}")
    print(f"  cat file_with_todos.py | aifixer > fixed_file.py")
    print(f"  {c['green']}# Or use a redirect (same result){c['reset']}")
    print(f"  aifixer < file_with_todos.py > fixed_file.py\n")
    
    # Model Selection
    print(f"{c['bold']}🧠 Model Selection{c['reset']}")
    print(f"  {c['green']}# Use Claude Opus (most powerful){c['reset']}")
    print(f"  cat complex_feature.py | aifixer --model anthropic/claude-3-opus-20240229 > implemented_feature.py")
    print(f"  {c['green']}# Use a local Ollama model (offline, self-hosted){c['reset']}")
    print(f"  cat file_with_todos.py | aifixer --ollama-model codellama > fixed_file.py")
    print(f"  {c['green']}# Automatically select the most economical model{c['reset']}")
    print(f"  cat complex_algorithm.py | aifixer --free > improved_algorithm.py\n")
    
    # Advanced File Handling
    print(f"{c['bold']}📂 Advanced File Handling{c['reset']}")
    print(f"  {c['green']}# Process a flattened codebase but only return the file with TODOs{c['reset']}")
    print(f"  codebase-to-text --input \"~/projects/my_project\" --output - --output_type \"txt\" | \\")
    print(f"    aifixer --fix-file-only > fixed_file.py")
    print(f"  {c['green']}# Target a specific file in a flattened codebase{c['reset']}")
    print(f"  codebase-to-text --input \"~/projects/my_project\" --output - --output_type \"txt\" | \\")
    print(f"    aifixer --fix-file-only --target-file \"src/utils.js\" > fixed_utils.js")
    print(f"  {c['green']}# List files with TODOs in a codebase{c['reset']}")
    print(f"  codebase-to-text --input \"~/projects/my_project\" --output - --output_type \"txt\" | \\")
    print(f"    aifixer --list-todo-files\n")
    
    # Custom Prompting
    print(f"{c['bold']}💡 Custom Prompting{c['reset']}")
    print(f"  {c['green']}# Fix bugs instead of TODOs{c['reset']}")
    print(f"  cat buggy_code.js | aifixer --prompt \"Find and fix all bugs in this code: \" > fixed_code.js")
    print(f"  {c['green']}# Add documentation to functions{c['reset']}")
    print(f"  cat undocumented.py | aifixer --prompt \"Add comprehensive docstrings to all functions: \" > documented.py")
    print(f"  {c['green']}# Optimize code performance{c['reset']}")
    print(f"  cat slow_algorithm.py | aifixer --prompt \"Optimize this algorithm for better performance: \" > fast_algorithm.py\n")
    
    # Power User Tricks
    print(f"{c['bold']}⚡ Power User Tricks{c['reset']}")
    print(f"  {c['green']}# In-place edit (requires moreutils package){c['reset']}")
    print(f"  aifixer < slow_function.rb | sponge slow_function.rb")
    print(f"  {c['green']}# See a diff of the changes{c['reset']}")
    print(f"  diff -u <(cat buggy_code.c) <(cat buggy_code.c | aifixer) | colordiff")
    print(f"  {c['green']}# Chain multiple transformations{c['reset']}")
    print(f"  cat code.js | aifixer --prompt \"Fix bugs: \" | aifixer --prompt \"Add type annotations: \" > fixed_typed_code.js")
    print(f"  {c['green']}# Git pre-commit hook to automatically fix TODOs{c['reset']}")
    print(f"  git diff --cached --name-only | xargs cat | aifixer | git apply\n")
    
    # Exploring Models
    print(f"{c['bold']}🔍 Exploring Available Models{c['reset']}")
    print(f"  {c['green']}# List OpenRouter models{c['reset']}")
    print(f"  aifixer --list-models")
    print(f"  {c['green']}# List local Ollama models{c['reset']}")
    print(f"  aifixer --list-ollama-models")
    print(f"  {c['green']}# Sort models by context window size{c['reset']}")
    print(f"  aifixer --list-models --sort-by context\n")
    
    print(f"{c['bold']}For more documentation:{c['reset']} https://github.com/yourusername/aifixer\n")

def print_banner():
    """Print the ASCII banner with terminal width detection"""
    # Get terminal width
    try:
        terminal_width = shutil.get_terminal_size().columns
    except (AttributeError, OSError):
        terminal_width = 80  # Default fallback
    
    # Print banner if terminal is wide enough
    if terminal_width >= 50:
        print(ASCII_BANNER)
    else:
        print("AIFixer v" + VERSION)

def get_term_colors():
    """Setup terminal color codes if supported"""
    colors = {
        'reset': '',
        'bold': '',
        'green': '',
        'yellow': '',
        'blue': '',
        'magenta': '',
        'cyan': '',
        'red': '',
    }
    
    # Only use colors if output is to a terminal
    if sys.stdout.isatty():
        colors['reset'] = '\033[0m'
        colors['bold'] = '\033[1m'
        colors['green'] = '\033[32m'
        colors['yellow'] = '\033[33m'
        colors['blue'] = '\033[34m'
        colors['magenta'] = '\033[35m'
        colors['cyan'] = '\033[36m'
        colors['red'] = '\033[31m'
    
    return colors

def main():
    # Get terminal colors
    c = get_term_colors()
    
    # Setup command line argument parsing
    parser = argparse.ArgumentParser(
        description=f"{c['bold']}AIFixer{c['reset']} - {c['cyan']}Terminal-native AI coding assistant{c['reset']}",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
        {c['bold']}What it does:{c['reset']} AIFixer brings AI coding assistance directly to your terminal workflow.
        It can complete TODOs, fix bugs, implement features, and more - all without leaving your terminal.
        
        {c['bold']}Basic examples:{c['reset']}
          {c['green']}cat file_with_todos.py | aifixer > fixed_file.py{c['reset']}
          {c['green']}cat file_with_bugs.js | aifixer --ollama-model codellama > fixed_file.js{c['reset']}
        
        {c['bold']}For more examples:{c['reset']} Use {c['yellow']}--help-examples{c['reset']} to see detailed usage examples.
        """
    )
    
    # General options
    parser.add_argument('--version', action='version', version=f'%(prog)s {VERSION}')
    parser.add_argument('--help-examples', action='store_true', help='Show detailed usage examples and exit')
    
    # Model selection options
    model_group = parser.add_argument_group('Model Selection')
    model_group.add_argument('--model', type=str, default="anthropic/claude-3-sonnet-20240229", 
                        help="OpenRouter model to use (default: anthropic/claude-3-sonnet-20240229)")
    model_group.add_argument('--ollama-model', type=str, 
                        help="Use a local Ollama model instead of OpenRouter")
    model_group.add_argument('--free', action='store_true', 
                        help="Auto-select a free model with the highest context window from OpenRouter")
    
    # Model listing options
    list_group = parser.add_argument_group('Model Listing')
    list_group.add_argument('--list-models', action='store_true', 
                        help="List available OpenRouter models and exit")
    list_group.add_argument('--list-ollama-models', action='store_true',
                        help="List available local Ollama models and exit")
    list_group.add_argument('--num-models', type=int, default=20, 
                        help="Number of models to display when listing OpenRouter models (default: 20)")
    list_group.add_argument('--sort-by', type=str, choices=['price', 'best', 'context'], default='price',
                        help="Sort OpenRouter models by price (default), context window size, or popularity")
    
    # Prompt options
    prompt_group = parser.add_argument_group('Prompt Configuration')
    prompt_group.add_argument('--prompt', type=str, 
                        default="Fix the TODOs in the file below and output the full file: ",
                        help="Custom prompt to prepend to the input")
    
    # File processing options
    file_group = parser.add_argument_group('File Processing')
    file_group.add_argument('--fix-file-only', action='store_true',
                       help="If input is a flattened codebase, only return the fixed file with TODOs")
    file_group.add_argument('--target-file', type=str,
                       help="Specify which file to fix in a flattened codebase")
    file_group.add_argument('--list-todo-files', action='store_true',
                       help="List files with TODOs in a flattened codebase and exit")
    
    # Positional argument for input text
    parser.add_argument('text', nargs='*', help="Input text (optional if using stdin)")
    
    args = parser.parse_args()
    
    # Handle the --help-examples option
    if args.help_examples:
        print_examples()
        return
    
    # Handle the model listing options
    if args.list_models:
        fetch_openrouter_models(args.num_models, auto_select=False, sort_key=args.sort_by)
        return
    
    if args.list_ollama_models:
        fetch_ollama_models()
        return
    
    # Handle the --free option
    if args.free and not args.ollama_model:
        import io
        from contextlib import redirect_stdout
        
        f = io.StringIO()
        with redirect_stdout(f):
            fetch_openrouter_models(1, auto_select=True, sort_key=args.sort_by)
        
        free_model = f.getvalue().strip()
        if free_model:
            args.model = free_model
    
    # Get input text
    input_text = ' '.join(args.text) if args.text else get_input()
    
    if not input_text:
        parser.print_help()
        return
    
    # Handle the --list-todo-files option
    if args.list_todo_files:
        files_with_todos = analyze_codebase_for_todos(input_text)
        if files_with_todos:
            print("Files containing TODOs:")
            for file in files_with_todos:
                print(f"  {file}")
        else:
            print("No files with TODOs found.")
        return
    
    # Start spinner and processing indicators only if output is to a terminal
    interactive_mode = sys.stdout.isatty()
    
    # Get terminal colors
    c = get_term_colors()
    
    # Show a spinner during API calls if in interactive mode
    if interactive_mode:
        print(f"{c['bold']}AIFixer:{c['reset']} {c['cyan']}Processing with AI...{c['reset']}", end="", flush=True)
        spinner_chars = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏']
        spinner_idx = 0
        start_time = time.time()
    
    
    # Process with the appropriate API
    try:
        if args.ollama_model:
            # Process with Ollama
            if sys.stdout.isatty():
                print(f" {c['magenta']}(using Ollama model: {args.ollama_model}){c['reset']}", end="", flush=True)
            
            # Show spinner during processing
            def spinner_update():
                nonlocal spinner_idx
                if sys.stdout.isatty():
                    elapsed = time.time() - start_time
                    print(f"\r{c['bold']}AIFixer:{c['reset']} {spinner_chars[spinner_idx]} {c['cyan']}Processing with Ollama{c['reset']} ({elapsed:.1f}s)", end="", flush=True)
                    spinner_idx = (spinner_idx + 1) % len(spinner_chars)
            
            # Setup spinner thread
            if sys.stdout.isatty():
                import threading
                stop_spinner = False
                
                def spin():
                    while not stop_spinner:
                        spinner_update()
                        time.sleep(0.1)
                
                spinner_thread = threading.Thread(target=spin)
                spinner_thread.start()
            
            # Process with Ollama
            output = process_with_ollama(
                args.ollama_model, 
                args.prompt, 
                input_text, 
                fix_file_only=args.fix_file_only,
                target_file=args.target_file
            )
            
            # Stop spinner
            if sys.stdout.isatty():
                stop_spinner = True
                spinner_thread.join()
                elapsed = time.time() - start_time
                print(f"\r{c['bold']}AIFixer:{c['reset']} {c['green']}✓ Done in {elapsed:.1f}s{c['reset']}                    ", flush=True)
                print()  # Extra line for cleaner output
        else:
            # Get the OpenRouter API key from environment
            api_key = os.environ.get("OPENROUTER_API_KEY")
            if not api_key:
                if sys.stdout.isatty():
                    print(f"\r{c['bold']}AIFixer:{c['reset']} {c['red']}Error: OPENROUTER_API_KEY environment variable not set{c['reset']}                    ")
                else:
                    print("Error: OPENROUTER_API_KEY environment variable not set")
                print("Please set it with: export OPENROUTER_API_KEY=your_api_key")
                sys.exit(1)
            
            # Show model info
            if sys.stdout.isatty():
                print(f" {c['magenta']}(using OpenRouter model: {args.model}){c['reset']}", end="", flush=True)
            
            # Show spinner during processing
            if sys.stdout.isatty():
                def spinner_update():
                    nonlocal spinner_idx
                    elapsed = time.time() - start_time
                    print(f"\r{c['bold']}AIFixer:{c['reset']} {spinner_chars[spinner_idx]} {c['cyan']}Processing with OpenRouter{c['reset']} ({elapsed:.1f}s)", end="", flush=True)
                    spinner_idx = (spinner_idx + 1) % len(spinner_chars)
                
                # Setup spinner thread
                import threading
                stop_spinner = False
                
                def spin():
                    while not stop_spinner:
                        spinner_update()
                        time.sleep(0.1)
                
                spinner_thread = threading.Thread(target=spin)
                spinner_thread.start()
            
            # Process with OpenRouter
            output = process_with_openrouter(
                api_key, 
                args.model, 
                args.prompt, 
                input_text,
                fix_file_only=args.fix_file_only,
                target_file=args.target_file
            )
            
            # Stop spinner
            if sys.stdout.isatty():
                stop_spinner = True
                spinner_thread.join()
                elapsed = time.time() - start_time
                print(f"\r{c['bold']}AIFixer:{c['reset']} {c['green']}✓ Done in {elapsed:.1f}s{c['reset']}                    ", flush=True)
                print()  # Extra line for cleaner output
    
    except KeyboardInterrupt:
        if sys.stdout.isatty():
            print(f"\r{c['bold']}AIFixer:{c['reset']} {c['yellow']}Operation cancelled{c['reset']}                    ")
        else:
            print("\nOperation cancelled")
        sys.exit(1)
    except Exception as e:
        if sys.stdout.isatty():
            print(f"\r{c['bold']}AIFixer:{c['reset']} {c['red']}Error: {str(e)}{c['reset']}                    ")
        else:
            print(f"Error: {str(e)}")
        sys.exit(1)
    
    # Print the response
    print(output)

def check_for_updates():
    """Check if a newer version is available"""
    try:
        response = requests.get("https://api.github.com/repos/yourusername/aifixer/releases/latest", timeout=1)
        if response.status_code == 200:
            latest_version = response.json().get("tag_name", "").lstrip("v")
            if latest_version and latest_version != VERSION:
                c = get_term_colors()
                print(f"{c['yellow']}A new version of AIFixer is available: v{latest_version} (you have v{VERSION}){c['reset']}")
                print(f"{c['yellow']}Update with: pip install --upgrade aifixer{c['reset']}")
    except:
        # Silently fail if we can't check for updates
        pass

if __name__ == "__main__":
    try:
        # Print banner only if running interactively (not being piped)
        interactive_mode = sys.stdout.isatty()
        if interactive_mode:
            print_banner()
            # Check for updates in the background
            import threading
            update_thread = threading.Thread(target=check_for_updates)
            update_thread.daemon = True
            update_thread.start()
        
        # Run the main program
        main()
    except KeyboardInterrupt:
        # Handle Ctrl+C gracefully
        if interactive_mode:
            c = get_term_colors()
            print(f"\n{c['yellow']}Operation cancelled by user{c['reset']}")
        else:
            print("\nOperation cancelled by user")
        sys.exit(1)
