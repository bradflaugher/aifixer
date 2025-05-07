# AIFixer for Windows

While AIFixer is primarily designed for Unix-like environments (Linux/macOS), it can be used on Windows. This guide provides detailed instructions for Windows users.

## Prerequisites

1. **Python**: Make sure Python is installed and added to your PATH.
   - Download from [python.org](https://www.python.org/downloads/windows/)
   - During installation, check "Add Python to PATH"

2. **Python Requests Library**:
   ```powershell
   # Install the requests library
   pip install requests
   ```

## Installation Options

### Option 1: PowerShell Installation Script

```powershell
# Create a directory for scripts if it doesn't exist
if (-not (Test-Path "$env:USERPROFILE\Scripts")) {
    New-Item -ItemType Directory -Path "$env:USERPROFILE\Scripts"
}

# Download AIFixer
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py" -OutFile "$env:USERPROFILE\Scripts\aifixer.py"

# Create a batch file wrapper
@"
@echo off
python "%USERPROFILE%\Scripts\aifixer.py" %*
"@ | Out-File -FilePath "$env:USERPROFILE\Scripts\aifixer.bat" -Encoding ascii

# Add the Scripts directory to your PATH (if not already there)
if (-not ($env:PATH -like "*$env:USERPROFILE\Scripts*")) {
    [Environment]::SetEnvironmentVariable("PATH", "$env:PATH;$env:USERPROFILE\Scripts", "User")
    echo "Added Scripts to PATH. Please restart your terminal or PowerShell session."
}
```

After running this script, restart your terminal or PowerShell session for the PATH changes to take effect.

### Option 2: Manual Installation

1. Download the AIFixer script:
   - Go to [https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py](https://raw.githubusercontent.com/bradflaugher/aifixer/main/aifixer.py)
   - Right-click and select "Save As"
   - Save to a location on your PATH (or create a directory and add it to your PATH)

2. Create a batch file wrapper (optional):
   - Create a file named `aifixer.bat` in the same directory with the following content:
     ```
     @echo off
     python path\to\aifixer.py %*
     ```

## Configuration

Set your OpenRouter API key:

```powershell
# For current PowerShell session only
$env:OPENROUTER_API_KEY = "your_api_key"

# To set permanently (system-wide)
[Environment]::SetEnvironmentVariable("OPENROUTER_API_KEY", "your_api_key", "User")
```

## Usage in Windows

Basic usage is similar to Linux/Mac but uses PowerShell syntax:

```powershell
# Pipe content to AIFixer
Get-Content file_with_todos.py | python path\to\aifixer.py > fixed_file.py

# Or if the wrapper is set up correctly and in your PATH:
Get-Content file_with_todos.py | aifixer > fixed_file.py
```

### Windows-specific Tips

1. **Using with Git Bash**: If you use Git Bash on Windows, you can use Unix-style commands:
   ```bash
   cat file_with_todos.py | aifixer > fixed_file.py
   ```

2. **Windows Terminal**: For a better terminal experience, consider using [Windows Terminal](https://github.com/microsoft/terminal)

3. **WSL Alternative**: For the best experience, consider using [Windows Subsystem for Linux (WSL)](https://learn.microsoft.com/en-us/windows/wsl/install) and follow the Linux installation instructions instead.

## Troubleshooting

### Common Issues

1. **Command Not Found**: If you get "aifixer is not recognized as an internal or external command":
   - Check that the Scripts directory is in your PATH
   - Verify that both aifixer.py and aifixer.bat exist in the Scripts directory
   - Try running `python %USERPROFILE%\Scripts\aifixer.py` directly

2. **Module Not Found Error**: If you get "No module named 'requests'":
   - Run `pip install requests` to install the required module

3. **Path Issues**: If you're having PATH-related problems:
   - Check your PATH with `echo %PATH%`
   - Add the Scripts directory manually: `setx PATH "%PATH%;%USERPROFILE%\Scripts"`

4. **Permission Issues**: If you encounter permission errors:
   - Run PowerShell as Administrator
   - Check that you have write access to the Scripts directory

For additional help, consult the [main README](./README.md) or open an issue on GitHub.
