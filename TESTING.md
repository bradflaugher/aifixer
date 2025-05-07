# AIFixer Test Script README

This document explains how to use the `test_aifixer.sh` script to run integration tests against the `aifixer` command‑line tool.

---

## Prerequisites

1. **`aifixer` Installed**  
   Make sure the `aifixer` executable is installed and available on your `PATH`. Follow the [AIFixer installation instructions](https://github.com/bradflaugher/aifixer) if you haven’t already.

2. **Bash**  
   A modern Bash shell (with support for `set -euo pipefail` and `trap`) is required.

3. **`mktemp`**  
   Used to create temporary files; available by default on most Linux and macOS systems.

4. **`grep`**  
   The script uses `grep` to check for TODOs and parse output.

5. **(Optional) `OPENROUTER_API_KEY`**  
   If you want to test OpenRouter‑based functionality, export your API key first:
   ```bash
   export OPENROUTER_API_KEY=your_api_key

If not set, tests that depend on OpenRouter may still run against a default or free‑tier model (if supported), or may warn/fail.
	6.	(Optional) Ollama
To test against a local Ollama server, install Ollama and ensure it’s running on http://localhost:11434. If not available, Ollama‑specific tests will be skipped or error out.

⸻

Installing & Running the Tests
	1.	Download or clone the test script into your AIFixer repo directory:

cp path/to/test_aifixer.sh .


	2.	Make it executable:

chmod +x test_aifixer.sh


	3.	Run the script:

./test_aifixer.sh

The script will automatically exit with status 0 if all tests pass, or 1 if any test fails.

⸻

What the Script Does
	1.	Strict mode (set -euo pipefail) to catch unbound variables, pipeline failures, and errors early.
	2.	Auto‑cleanup of all temporary files via a trap on EXIT.
	3.	Prerequisite checks for aifixer, OPENROUTER_API_KEY, and other utilities.
	4.	Five core tests:
	1.	--version: Ensures aifixer --version prints a semantic version (e.g. 1.1.0).
	2.	--help: Verifies usage text appears (looks for “usage:”).
	3.	Basic TODO removal: Pipes a small Python snippet with one TODO into AIFixer and checks that the number of TODO annotations decreases.
	4.	--list-todo-files with TODOs: Uses a two‑file flatten (only one has a TODO) and ensures only the correct filename is printed.
	5.	--list-todo-files with no TODOs: Confirms AIFixer reports “no TODOs” when appropriate.

Each test prints a colored PASS or FAIL message, plus a reason if it fails. At the end, a summary shows how many tests ran and how many passed.

⸻

Interpreting Results
	•	PASS (green): The test behaved as expected.
	•	FAIL (red): The test did not meet expectations; a brief “Reason” will be shown.
	•	Warnings: If optional dependencies are missing (e.g. no OPENROUTER_API_KEY), you’ll see a warning, but the script will proceed.

⸻

Extending the Test Suite

This framework is intentionally minimal. You can add more tests by copying the helper functions and following the existing pattern. Some ideas:
	•	Model listing: Verify that --list-models and --list-ollama-models produce non‑empty tables.
	•	--free flag: Confirm that the --free shortcut picks a valid free model.
	•	Custom prompts: Pipe in code with a custom prompt and validate a keyword appears in the output.
	•	Error conditions: Run without OPENROUTER_API_KEY (when no Ollama) and expect a non‑zero exit and an explanatory error message.

Note: Because AI output is non‑deterministic, tests focus on exit codes, the presence or absence of key markers (like TODO), and correct CLI plumbing (stdout vs stderr), rather than exact code diffs.

⸻

Troubleshooting
	1.	aifixer not found
Make sure you installed it and that it’s on your PATH.
	2.	Permission denied
Ensure test_aifixer.sh is executable:

chmod +x test_aifixer.sh


	3.	Unexpected FAIL
Read the “Reason” printed under the failed test. You can rerun that single test block manually, or add set -x to the top of the script to see each command as it runs.
	4.	Cleanup issues
On rare occasions, the trap may not fire (e.g. if you kill the script with kill -9). Temporary files live under /tmp/aifixer_test_*; feel free to delete them manually.

⸻

With this in place, you’ll have a quick, repeatable sanity check for every change to AIFixer! Feel free to submit additional test cases as PRs to the repository.