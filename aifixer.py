#!/usr/bin/env python3
# aifixer.py — Terminal‑native AI coding assistant (v1.1.0 → improved)

import argparse
import json
import logging
import os
import platform
import re
import shutil
import sys
import threading
import time
from contextlib import contextmanager
from textwrap import dedent
from typing import Any, Dict, List, Optional

import requests  # requires only `requests`

VERSION = "1.1.0"
OPENROUTER_URL = "https://openrouter.ai/api/v1"
OLLAMA_URL = "http://localhost:11434/api"
REQUEST_TIMEOUT = 10  # seconds

# ─── Setup Logging ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(levelname)s: %(message)s",
    stream=sys.stderr,
)
logger = logging.getLogger("aifixer")


# ─── Utility Functions ────────────────────────────────────────────────────────
def format_size(size_bytes: int) -> str:
    """Convert bytes to human-readable form."""
    if size_bytes == 0:
        return "0B"
    size_names = ("B", "KB", "MB", "GB", "TB")
    i = 0
    size = float(size_bytes)
    while size >= 1024 and i < len(size_names) - 1:
        size /= 1024
        i += 1
    return f"{size:.2f} {size_names[i]}"


def analyze_codebase_for_todos(text: str) -> List[str]:
    """Return list of filenames (from '# File: ...') containing TODO or FIXME."""
    file_pattern = r"# File: (.+)"
    parts = re.split(file_pattern, text)[1:]
    results = []
    for fname, content in zip(parts[0::2], parts[1::2]):
        if re.search(r"(?i)\bTODO\b|\bFIXME\b", content):
            results.append(fname)
    return results


def build_fix_prompt(base_prompt: str, fix_only: bool, target_file: Optional[str]) -> str:
    """Return either the custom prompt or the 'fix-file-only' variant."""
    if not fix_only:
        return base_prompt
    if target_file:
        return (
            f"Fix the TODOs in the file '{target_file}' from the codebase below. "
            "Only return the complete fixed version of that file, nothing else. "
            "Do not include any explanations, headers, or markdown formatting: "
        )
    return (
        "Fix the TODOs in the code below. If this is a flattened codebase, "
        "identify the file that has TODOs and only return the complete fixed "
        "version of that file. Do not include any explanations, headers, or "
        "markdown formatting: "
    )


def extract_fixed_file(output: str) -> str:
    """Strip markdown/code fences and return just the code."""
    # First look for fenced code blocks
    blocks = re.findall(r"```(?:\w+)?\s*([\s\S]+?)\s*```", output)
    if blocks:
        return max(blocks, key=len).strip()

    # Otherwise, remove introductory lines, headers, etc.
    cleaned = re.sub(r"^#+ .*\n", "", output, flags=re.MULTILINE)
    cleaned = re.sub(
        r".*?(?=(?:def |class |import |package |<\?php|\<\!DOCTYPE|\<html))", "", cleaned, flags=re.DOTALL
    )
    return cleaned.strip()


@contextmanager
def spinner(message: str):
    """Simple terminal spinner with ASCII chars for universal compatibility."""
    # Only show spinner when stderr is connected to a terminal
    if not sys.stderr.isatty():
        yield
        return

    # Simple ASCII spinner chars that work everywhere
    chars = ["-", "\\", "|", "/"]
    stop = False

    def run_spin():
        idx = 0
        while not stop:
            sys.stderr.write(f"\r{message} {chars[idx]} ")
            sys.stderr.flush()
            time.sleep(0.1)
            idx = (idx + 1) % len(chars)
        sys.stderr.write("\r" + " " * (len(message) + 4) + "\r")
        sys.stderr.flush()

    thread = threading.Thread(target=run_spin)
    thread.daemon = True  # Make thread daemon so it exits when main thread does
    thread.start()
    try:
        yield
    finally:
        stop = True
        thread.join(timeout=0.5)  # Add timeout to avoid hanging


# ─── Model Listing & Selection ───────────────────────────────────────────────────
def get_free_models(session: requests.Session, sort_key: str = "price") -> List[str]:
    """Return a list of free model IDs from OpenRouter, sorted by the given criteria."""
    url = f"{OPENROUTER_URL}/models"
    try:
        resp = session.get(url, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json().get("data", [])
    except Exception as e:
        logger.error("Could not fetch OpenRouter models: %s", e)
        sys.exit(1)

    # filter to get only free models
    free_models = [
        m for m in data
        if m.get("pricing") and m.get("id") != "openrouter/auto" 
        and m.get("pricing", {}).get("prompt", float("inf")) == 0
    ]
    
    # Sort models using the specified criteria
    sorters = {
        "price": lambda m: (-m.get("context_length", 0)),  # For free models, sort by context length
        "best":  lambda m: (-m.get("context_length", 0)),  # Same as above for free models
        "context": lambda m: (-int(m.get("context_length", 0))),
    }
    free_models.sort(key=sorters[sort_key])
    
    # Return full model IDs including :free suffix if needed
    result = []
    for m in free_models:
        model_id = m["id"]
        if not model_id.endswith(":free"):
            model_id = f"{model_id}:free"
        result.append(model_id)
    
    return result


def fetch_openrouter_models(
    session: requests.Session,
    num: int,
    sort_key: str = "price",
) -> None:
    """Fetch & display top OpenRouter models."""
    url = f"{OPENROUTER_URL}/models"
    try:
        resp = session.get(url, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        data = resp.json().get("data", [])
    except Exception as e:
        logger.error("Could not fetch OpenRouter models: %s", e)
        sys.exit(1)

    # filter & sort
    models = [
        m for m in data
        if m.get("pricing") and m.get("id") != "openrouter/auto"
    ]
    sorters = {
        "price": lambda m: (m["pricing"].get("prompt", float("inf")), -m.get("context_length", 0)),
        "best":  lambda m: (-float(m["pricing"].get("prompt", 0)), -m.get("context_length", 0)),
        "context": lambda m: (-int(m.get("context_length", 0)), m["pricing"].get("prompt", float("inf"))),
    }
    models.sort(key=sorters[sort_key])
    chosen = models[:num]

    # table header
    headers = ["Model ID", "Context", "Prompt", "Completion", "Description"]
    widths = [len(h) for h in headers]
    for m in chosen:
        widths[0] = max(widths[0], len(m["id"]))
        widths[1] = max(widths[1], len(str(m.get("context_length", ""))))
        widths[2] = max(widths[2], len(str(m["pricing"]["prompt"])))
        widths[3] = max(widths[3], len(str(m["pricing"]["completion"])))

    hdr = " | ".join(f"{h:<{widths[i]}}" for i, h in enumerate(headers[:-1])) + f" | {headers[-1]}"
    print(hdr)
    print("-" * len(hdr))

    for m in chosen:
        desc = m.get("description", "").replace("\n", " ")
        if len(desc) > 135:
            desc = desc[:135] + "..."
        row = [
            m["id"],
            str(m.get("context_length", "")),
            str(m["pricing"]["prompt"]),
            str(m["pricing"]["completion"]),
            desc,
        ]
        line = " | ".join(f"{row[i]:<{widths[i]}}" for i in range(len(row)-1))
        print(f"{line} | {row[-1]}")


def fetch_ollama_models(session: requests.Session) -> None:
    """Fetch & display available Ollama models."""
    url = f"{OLLAMA_URL}/tags"
    try:
        resp = session.get(url, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        models = resp.json().get("models", [])
    except requests.exceptions.ConnectionError:
        logger.error("Cannot connect to Ollama at %s", url)
        return
    except Exception as e:
        logger.error("Error fetching Ollama models: %s", e)
        return

    headers = ["Name", "Size", "Modified", "Family"]
    widths = [len(h) for h in headers]
    for m in models:
        widths[0] = max(widths[0], len(m.get("name", "")))
        widths[1] = max(widths[1], len(format_size(m.get("size", 0))))
        widths[2] = max(widths[2], len(m.get("modified", "")))
        widths[3] = max(widths[3], len(m.get("details", {}).get("family", "")))

    hdr = " | ".join(f"{h:<{widths[i]}}" for i, h in enumerate(headers))
    print(hdr)
    print("-" * len(hdr))

    for m in models:
        fam = m["details"].get("family", "")
        row = [
            m["name"],
            format_size(m["size"]),
            m["modified"],
            fam,
        ]
        print(" | ".join(f"{row[i]:<{widths[i]}}" for i in range(len(row))))


# ─── Processing Functions ─────────────────────────────────────────────────────
def process_with_openrouter(
    session: requests.Session,
    api_key: str,
    model: str,
    prompt: str,
    input_text: str,
    fix_only: bool,
    target_file: Optional[str],
    retry_models: Optional[List[str]] = None,
) -> str:
    """Send prompt+input to OpenRouter and return AI response (or fixed code).
    
    If retry_models is provided, will attempt those models in order on failure.
    """
    p = build_fix_prompt(prompt, fix_only, target_file) + input_text
    url = f"{OPENROUTER_URL}/chat/completions"
    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    
    # Use the full model name exactly as provided, just like the original code
    current_model = model
    payload = {"model": current_model, "messages": [{"role": "user", "content": p}]}
    
    logger.debug(f"Using model: {current_model}")

    try:
        resp = session.post(url, headers=headers, json=payload, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        content = resp.json()["choices"][0]["message"]["content"]
        return extract_fixed_file(content) if fix_only else content
    
    except Exception as e:
        error_msg = f"Error with model {current_model}: {e}"
        
        # If we have retry models, attempt them in sequence
        if retry_models:
            logger.warning(f"{error_msg} - Trying fallback models...")
            
            for fallback_model in retry_models:
                if fallback_model == current_model:
                    continue  # Skip the one we just tried
                
                logger.info(f"Trying fallback model: {fallback_model}")
                payload["model"] = fallback_model
                
                try:
                    resp = session.post(url, headers=headers, json=payload, timeout=REQUEST_TIMEOUT)
                    resp.raise_for_status()
                    content = resp.json()["choices"][0]["message"]["content"]
                    logger.info(f"✓ Fallback model {fallback_model} succeeded")
                    return extract_fixed_file(content) if fix_only else content
                except Exception as fallback_e:
                    logger.warning(f"Fallback model {fallback_model} failed: {fallback_e}")
                    continue  # Try the next model in the list
            
            # If we get here, all fallbacks failed
            logger.error("All models failed. Last error:")
        
        # Print detailed error for the last attempt
        try:
            logger.error(f"OpenRouter error ({resp.status_code}): {e}")
            logger.error(f"Response content: {resp.text[:200]}...")
        except:
            logger.error(f"OpenRouter error: {e}")
        
        sys.exit(1)


def process_with_ollama(
    session: requests.Session,
    model: str,
    prompt: str,
    input_text: str,
    fix_only: bool,
    target_file: Optional[str],
) -> str:
    """Send prompt+input to local Ollama and return AI response (or fixed code)."""
    p = build_fix_prompt(prompt, fix_only, target_file) + input_text
    url = f"{OLLAMA_URL}/chat"
    payload = {"model": model, "messages": [{"role": "user", "content": p}]}

    try:
        resp = session.post(url, json=payload, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
        content = resp.json().get("message", {}).get("content", "")
    except requests.exceptions.ConnectionError:
        logger.error("Cannot connect to Ollama at %s", url)
        sys.exit(1)
    except Exception as e:
        logger.error("Ollama error (%s): %s", getattr(resp, "status_code", ""), e)
        sys.exit(1)

    return extract_fixed_file(content) if fix_only else content


# ─── CLI & Main ───────────────────────────────────────────────────────────────
def print_version() -> None:
    """Print a simple version message."""
    print(f"AIFixer v{VERSION}", file=sys.stderr)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="AIFixer — Terminal-native AI coding assistant",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    # Global flags
    parser.add_argument("--version", action="version", version=VERSION)
    parser.add_argument("--help-examples", action="store_true")

    # Model selection
    mg = parser.add_argument_group("Model Selection")
    mg.add_argument("--model", default="anthropic/claude-3-sonnet-20240229")
    mg.add_argument("--ollama-model")
    mg.add_argument("--free", action="store_true")
    mg.add_argument("--max-fallbacks", type=int, default=2, 
                   help="Number of fallback models to try if free model fails (default: 2)")

    # Listing
    lg = parser.add_argument_group("Model Listing")
    lg.add_argument("--list-models", action="store_true")
    lg.add_argument("--list-ollama-models", action="store_true")
    lg.add_argument("--num-models", type=int, default=20)
    lg.add_argument("--sort-by", choices=["price", "best", "context"], default="price")

    # Prompt & file options
    pg = parser.add_argument_group("Prompt & File Options")
    pg.add_argument("--prompt", default="Fix the TODOs in the file below and output the full file: ")
    pg.add_argument("--fix-file-only", action="store_true")
    pg.add_argument("--target-file")
    pg.add_argument("--list-todo-files", action="store_true")

    parser.add_argument("text", nargs="*", help="Input text (or use stdin)")

    args = parser.parse_args()
    session = requests.Session()

    # Examples, listings, etc.
    if args.help_examples:
        print(dedent(  # kept short for clarity
            """
            Examples:
              cat file.py | aifixer --model anthro/claude > fixed.py
              aifixer --list-models
            """
        ), file=sys.stderr)
        return

    if args.list_models:
        fetch_openrouter_models(session, args.num_models, sort_key=args.sort_by)
        return

    if args.list_ollama_models:
        fetch_ollama_models(session)
        return

    # Print a simple version message for interactive use
    if sys.stderr.isatty():
        print_version()

    # Free model auto‑select with fallbacks
    fallback_models = []
    if args.free and not args.ollama_model:
        with spinner("Selecting free models…"):
            free_models = get_free_models(session, sort_key=args.sort_by)
            
        if not free_models:
            logger.error("No free models found")
            sys.exit(1)
            
        # Set primary model and keep others as fallbacks
        args.model = free_models[0]
        fallback_models = free_models[1:args.max_fallbacks+1]  # Limit fallbacks
        
        logger.info(f"Selected free model: {args.model}")
        if fallback_models:
            logger.info(f"Fallback models: {', '.join(fallback_models)}")

    # Gather input_text
    if args.text:
        input_text = " ".join(args.text)
    elif not sys.stdin.isatty():
        input_text = sys.stdin.read()
    else:
        parser.print_help(sys.stderr)
        return

    # List TODO files
    if args.list_todo_files:
        todos = analyze_codebase_for_todos(input_text)
        out = "\n".join(todos) if todos else "No TODOs found."
        print(out)
        return

    # Process
    api_key = os.getenv("OPENROUTER_API_KEY", "")
    if not args.ollama_model and not api_key:
        logger.error("OPENROUTER_API_KEY not set; export it and retry.")
        sys.exit(1)

    start_time = time.time()
    try:
        if args.ollama_model:
            with spinner(f"Processing via Ollama ({args.ollama_model})…"):
                result = process_with_ollama(
                    session, args.ollama_model, args.prompt,
                    input_text, args.fix_file_only, args.target_file
                )
        else:
            with spinner(f"Processing via OpenRouter ({args.model})…"):
                result = process_with_openrouter(
                    session, api_key, args.model, args.prompt,
                    input_text, args.fix_file_only, args.target_file,
                    retry_models=fallback_models
                )
    except KeyboardInterrupt:
        logger.warning("Operation cancelled by user.")
        sys.exit(1)

    # Show completion message with timing
    elapsed = time.time() - start_time
    if sys.stderr.isatty():
        logger.info(f"Completed in {elapsed:.1f}s ✓")

    # AI output → stdout (for piping)
    sys.stdout.write(result)


if __name__ == "__main__":
    main()