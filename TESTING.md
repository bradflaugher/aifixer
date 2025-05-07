# AIFixer Test Script README

This document provides instructions on how to use the `test_aifixer.sh` script to test the `aifixer` command-line tool.

## Prerequisites

Before running the test script, please ensure the following prerequisites are met:

1.  **`aifixer` Installed**: The `aifixer` command-line tool must be installed and accessible in your system's PATH. You can typically install it by following the instructions in the [AIFixer GitHub repository](https://github.com/bradflaugher/aifixer).
2.  **Bash**: The script is written in Bash and requires a Bash-compatible shell to run.
3.  **`mktemp`**: The script uses `mktemp` to create temporary files. This utility is commonly available on Linux and macOS systems.
4.  **(Optional) `OPENROUTER_API_KEY`**: For tests involving OpenRouter models, you need to have the `OPENROUTER_API_KEY` environment variable set. If not set, tests specifically requiring this key might be skipped or use default free-tier models if `aifixer` supports that.
5.  **(Optional) Ollama**: For tests involving local Ollama models, you need to have Ollama installed and the Ollama server running. The script will attempt to detect if Ollama is running. If not, Ollama-specific tests will be skipped. You can install Ollama from [ollama.ai](https://ollama.ai/).
6.  **(Optional) `sponge`**: For the in-place editing test case, the `sponge` utility (part of `moreutils`) is required. If not installed, this specific test will be skipped. You can usually install it via your system's package manager (e.g., `sudo apt-get install moreutils` on Debian/Ubuntu, `brew install moreutils` on macOS).

## How to Run the Script

1.  Save the `test_aifixer.sh` script to your local machine.
2.  Make the script executable:
    ```bash
    chmod +x test_aifixer.sh
    ```
3.  Run the script from your terminal:
    ```bash
    ./test_aifixer.sh
    ```

## Script Overview

The script performs the following actions:

*   Checks for the presence of `aifixer` and other optional dependencies.
*   Runs a series of test cases based on the functionalities described in the AIFixer README.
*   Currently, it includes a basic test case for fixing TODOs in a Python file using the default `aifixer` behavior.
*   Prints PASS/FAIL status for each test case.
*   Provides a summary of the test results.

## Interpreting Results

*   **PASS**: Indicates that the test case executed as expected (e.g., `aifixer` command ran successfully, and for TODO fixing, the number of "TODO" instances decreased).
*   **FAIL**: Indicates that the test case did not meet the expected outcome. The script will provide a reason for the failure.
*   **Warnings**: The script may print warnings if optional dependencies (like `OPENROUTER_API_KEY`, Ollama, or `sponge`) are not found. Tests relying on these dependencies might be skipped.

## Current Status & Further Development

This script provides a foundational framework and an initial test case. The `todo.md` file (also provided) outlines further test cases that can be implemented to cover more features of `aifixer`, such as:

*   Testing with specific OpenRouter models.
*   Testing with Ollama models.
*   Testing the `--free` flag.
*   Testing in-place file editing.
*   Testing model listing commands.
*   Testing custom prompts.

Due to the non-deterministic nature of AI output, the script primarily checks for successful command execution and general indications of success (like a reduction in TODOs) rather than exact output matching for AI-generated code.

## Important Note

The script was developed in an environment where `aifixer` was not pre-installed. The initial run of the script will likely fail the prerequisite check for `aifixer`. Please ensure `aifixer` is correctly installed before running the tests.

