#!/usr/bin/env python3
"""
Generates a sketch explainer image using the Gemini API (Nano Banana 2).

Usage:
    python generate_image.py <topic-slug> --prompt-file <path>
    python generate_image.py <topic-slug> --prompt "full prompt text"
    echo "prompt" | python generate_image.py <topic-slug>

Requires:
    pip install google-genai Pillow
    GEMINI_API_KEY environment variable set
"""

import sys
import os
import re
import argparse
from datetime import datetime
from pathlib import Path


def _load_api_key():
    """Load GEMINI_API_KEY from config.env (skill root), falling back to env var."""
    config_path = Path(__file__).parent.parent / "config.env"
    if config_path.exists():
        for line in config_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            if key.strip() == "GEMINI_API_KEY":
                value = value.strip()
                if value and value != "your-api-key-here":
                    return value
    return os.environ.get("GEMINI_API_KEY")


def slugify(text):
    text = re.sub(r"[^\w\s-]", "", text.lower())
    return re.sub(r"[\s_-]+", "-", text).strip("-")[:60]


def main():
    parser = argparse.ArgumentParser(description="Generate sketch explainer image via Gemini API")
    parser.add_argument("topic_slug", help="Short kebab-case label for the topic, e.g. wealth-creation")
    parser.add_argument("--prompt", help="Full image prompt as a string")
    parser.add_argument("--prompt-file", help="Path to a text file containing the image prompt")
    args = parser.parse_args()

    # Resolve prompt
    if args.prompt_file:
        prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    elif args.prompt:
        prompt = args.prompt.strip()
    elif not sys.stdin.isatty():
        prompt = sys.stdin.read().strip()
    else:
        print("Error: provide --prompt, --prompt-file, or pipe prompt via stdin.", file=sys.stderr)
        sys.exit(1)

    if not prompt:
        print("Error: prompt is empty.", file=sys.stderr)
        sys.exit(1)

    # Output directory: generated-images/ sibling to this scripts/ folder
    output_dir = Path(__file__).parent.parent / "generated-images"
    output_dir.mkdir(exist_ok=True)

    slug = slugify(args.topic_slug)
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_path = output_dir / f"{slug}-{timestamp}.png"

    # Resolve API key: config.env file takes priority, env var as fallback
    api_key = _load_api_key()
    if not api_key:
        config_path = Path(__file__).parent.parent / "config.env"
        print("Error: GEMINI_API_KEY not found.", file=sys.stderr)
        print(f"  Set it in: {config_path}", file=sys.stderr)
        print("  Or set env var: $env:GEMINI_API_KEY = 'your-key'", file=sys.stderr)
        sys.exit(1)

    # Import Gemini client
    try:
        from google import genai
    except ImportError:
        print("Error: google-genai not installed. Run: pip install google-genai Pillow", file=sys.stderr)
        sys.exit(1)

    print(f"Topic   : {slug}")
    print(f"Prompt  : {len(prompt)} chars")
    print(f"Calling : gemini-3.1-flash-image-preview ...")

    client = genai.Client(api_key=api_key)

    response = client.models.generate_content(
        model="gemini-3.1-flash-image-preview",
        contents=[prompt],
    )

    saved = False
    for part in response.parts:
        if part.text is not None:
            print(f"[model] {part.text}")
        elif part.inline_data is not None:
            image = part.as_image()
            image.save(str(output_path))
            print(f"Saved   : {output_path}")
            saved = True
            break

    if not saved:
        print("Error: API returned no image. Check prompt or API quota.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
