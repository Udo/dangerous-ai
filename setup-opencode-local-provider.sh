#!/usr/bin/env bash
set -euo pipefail

BASE_URL="http://10.8.4.40/v1"
API_KEY="dummy"
TARGET=""

usage() {
	cat <<EOF
Usage: $(basename "$0") <ssh-target> [OPTIONS]

Install opencode from the official upstream installer on a remote host, then
configure it to use the local OpenAI-compatible endpoint as a custom provider.

Arguments:
  ssh-target              SSH host to install onto (for example: uh-cli-runner)

Options:
  --base-url URL          OpenAI-compatible base URL
                          Default: $BASE_URL
  --api-key KEY           API key written into opencode config
                          Default: $API_KEY
  -h, --help              Show this help

Notes:
  Official install source: https://opencode.ai/install
  Config written to: ~/.config/opencode/opencode.json
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--base-url)
			BASE_URL="$2"
			shift 2
			;;
		--api-key)
			API_KEY="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		--*)
			echo "Unknown option: $1" >&2
			usage >&2
			exit 1
			;;
		*)
			if [[ -n "$TARGET" ]]; then
				echo "Target already set: $TARGET" >&2
				usage >&2
				exit 1
			fi
			TARGET="$1"
			shift
			;;
	esac
done

if [[ -z "$TARGET" ]]; then
	echo "Missing ssh target" >&2
	usage >&2
	exit 1
fi

cat <<'REMOTE' | ssh "$TARGET" /bin/bash -s -- "$BASE_URL" "$API_KEY"
set -euo pipefail

BASE_URL="$1"
API_KEY="$2"
CONFIG_DIR="$HOME/.config/opencode"
CONFIG_FILE="$CONFIG_DIR/opencode.json"

echo "Installing opencode from official installer..." >&2
curl -fsSL https://opencode.ai/install | bash

OPENCODE_BIN="$(command -v opencode 2>/dev/null || true)"
if [[ -z "$OPENCODE_BIN" ]]; then
	for candidate in "$HOME/.local/bin/opencode" "$HOME/bin/opencode" "/usr/local/bin/opencode"; do
		if [[ -x "$candidate" ]]; then
			OPENCODE_BIN="$candidate"
			break
		fi
	done
fi

if [[ -z "$OPENCODE_BIN" ]]; then
	echo "opencode installation succeeded but binary was not found in PATH or common install locations" >&2
	exit 1
fi

install -d -m 755 "$CONFIG_DIR"

python3 - "$BASE_URL" "$API_KEY" "$CONFIG_FILE" <<'PY'
import json
import sys
import urllib.request
from pathlib import Path

base = sys.argv[1].rstrip("/")
api_key = sys.argv[2]
config_path = Path(sys.argv[3])

models = json.load(urllib.request.urlopen(base + "/models", timeout=15)).get("data", [])
provider_models = {}
for model in models:
    mid = model["id"]
    provider_models[mid] = {"name": mid}

default_model = next((m["id"] for m in models if "embedding" not in m["id"].lower()), None)
if default_model is None and models:
    default_model = models[0]["id"]

config = {
    "$schema": "https://opencode.ai/config.json",
    "provider": {
        "local": {
            "npm": "@ai-sdk/openai-compatible",
            "name": "Local LLM",
            "options": {
                "baseURL": base,
                "apiKey": api_key,
            },
            "models": provider_models,
        }
    },
    "model": "local/" + default_model if default_model else None,
}

if config["model"] is None:
    del config["model"]

config_path.write_text(json.dumps(config, indent=2) + "\n")
PY

echo "Installed binary: $OPENCODE_BIN" >&2
"$OPENCODE_BIN" --version
printf '\n--- config ---\n'
OPENCODE_CONFIG="$CONFIG_FILE" "$OPENCODE_BIN" debug config
printf '\n--- models ---\n'
OPENCODE_CONFIG="$CONFIG_FILE" "$OPENCODE_BIN" models local | sed -n '1,20p'
REMOTE

