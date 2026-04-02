#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/_common.sh"
ai::setup_path

API_URL=""
MODEL=""
SERVER=""

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS] [goose args...]

Options:
  --api-url URL         Custom OpenAI-compatible API endpoint for this session
  --model MODEL         Model to use
  --server ADDR:PORT    Add/update a persistent OpenAI/Ollama-compatible server in goose config
  -h, --help            Show this help message
EOF
}

normalize_server_url() {
	local raw="$1"

	if [[ "$raw" == http://* ]] || [[ "$raw" == https://* ]]; then
		printf '%s\n' "$raw"
	else
		printf 'http://%s\n' "$raw"
	fi
}

configure_server() {
	local server_input="$1"
	local server_url config_path

	server_url="$(normalize_server_url "$server_input")"
	config_path="$HOME/.config/goose/config.yaml"

	SERVER_URL="$server_url" CONFIG_PATH="$config_path" MODEL_OVERRIDE="$MODEL" python3 - <<'PY'
import json
import os
import re
import sys
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

server_url = os.environ["SERVER_URL"].rstrip("/")
config_path = Path(os.environ["CONFIG_PATH"]).expanduser()
model_override = os.environ.get("MODEL_OVERRIDE", "").strip()

base_origin = server_url[:-3] if server_url.endswith("/v1") else server_url


def fetch_json(url):
    req = Request(url, headers={"Accept": "application/json"})
    with urlopen(req, timeout=5) as resp:
        charset = resp.headers.get_content_charset() or "utf-8"
        return json.loads(resp.read().decode(charset))


errors = []
model_ids = []

for url in (f"{server_url}/v1/models", f"{base_origin}/v1/models"):
    try:
        payload = fetch_json(url)
        data = payload.get("data") or []
        model_ids = [item.get("id") for item in data if isinstance(item, dict) and item.get("id")]
        if model_ids:
            break
        errors.append((url, "no models returned"))
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
        errors.append((url, str(exc)))

if not model_ids:
    for url in (f"{base_origin}/api/tags", f"{server_url}/api/tags"):
        try:
            payload = fetch_json(url)
            data = payload.get("models") or []
            model_ids = [item.get("name") for item in data if isinstance(item, dict) and item.get("name")]
            if model_ids:
                break
            errors.append((url, "no models returned"))
        except (HTTPError, URLError, TimeoutError, json.JSONDecodeError, OSError) as exc:
            errors.append((url, str(exc)))

if not model_ids:
    print("Could not detect models from the server.", file=sys.stderr)
    for url, message in errors:
        print(f"  {url}: {message}", file=sys.stderr)
    sys.exit(1)

selected_model = model_override or next((mid for mid in model_ids if "embedding" not in mid.lower()), model_ids[0])
base_path = "v1/chat/completions"

content = ""
if config_path.exists():
    content = config_path.read_text(encoding="utf-8")

if content and not content.endswith("\n"):
    content += "\n"


def yaml_quote(value):
    return json.dumps(value)


def upsert_scalar(text, key, value):
    pattern = re.compile(rf"(?m)^(?!\s*#)\s*{re.escape(key)}\s*:\s*.*$")
    line = f"{key}: {yaml_quote(value)}"
    if pattern.search(text):
        return pattern.sub(line, text, count=1)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + line + "\n"


content = upsert_scalar(content, "GOOSE_PROVIDER", "openai")
content = upsert_scalar(content, "GOOSE_MODEL", selected_model)
content = upsert_scalar(content, "OPENAI_HOST", base_origin)
content = upsert_scalar(content, "OPENAI_BASE_PATH", base_path)

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text(content, encoding="utf-8")

print(f"Configured goose server in {config_path}", file=sys.stderr)
print(f"  GOOSE_PROVIDER: openai", file=sys.stderr)
print(f"  GOOSE_MODEL: {selected_model}", file=sys.stderr)
print(f"  OPENAI_HOST: {base_origin}", file=sys.stderr)
print(f"  OPENAI_BASE_PATH: {base_path}", file=sys.stderr)
for model_id in model_ids:
    print(f"  - {model_id}", file=sys.stderr)
PY
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--api-url)
			API_URL="$2"
			shift 2
			;;
		--model)
			MODEL="$2"
			shift 2
			;;
		--server)
			SERVER="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			break
			;;
	esac
done

self_path="$(ai::self_path "$0")"
goose_bin="$(ai::resolve_bin goose "$self_path" "$HOME/.local/bin/goose" "$HOME/bin/goose" || true)"

if [[ -z "$goose_bin" ]] || [[ "$(readlink -f "$goose_bin")" == "$self_path" ]]; then
	echo "Installing goose..." >&2
	curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash >&2
	ai::refresh_shell
	goose_bin="$(ai::resolve_bin goose "$self_path" "$HOME/.local/bin/goose" "$HOME/bin/goose" || true)"
	if [[ -z "$goose_bin" ]] || [[ "$(readlink -f "$goose_bin")" == "$self_path" ]]; then
		echo "goose installation failed" >&2
		exit 1
	fi
fi

if [[ -n "$SERVER" ]]; then
	configure_server "$SERVER"
fi

if [[ -n "$API_URL" ]]; then
	server_url="$(normalize_server_url "$API_URL")"
	if [[ "$server_url" == */v1 ]]; then
		export OPENAI_HOST="${server_url%/v1}"
	else
		export OPENAI_HOST="$server_url"
	fi
	export OPENAI_BASE_PATH="v1/chat/completions"
	export GOOSE_PROVIDER="openai"
fi

if [[ -n "$MODEL" ]]; then
	export GOOSE_MODEL="$MODEL"
fi

"$goose_bin" "$@"
