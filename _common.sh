#!/usr/bin/env bash

set -euo pipefail

ai::setup_path() {
	export PATH="$HOME/.local/bin:$HOME/bin:$HOME/.cargo/bin:$HOME/.opencode/bin:/usr/local/bin:$PATH"
}

ai::refresh_shell() {
	hash -r 2>/dev/null || true
}

ai::self_path() {
	readlink -f "$1"
}

ai::resolve_bin() {
	local name="$1"
	local self_path="${2:-}"
	shift 2 || true

	local candidate=""
	candidate="$(command -v "$name" 2>/dev/null || true)"
	if [[ -n "$candidate" ]]; then
		candidate="$(readlink -f "$candidate")"
		if [[ -z "$self_path" ]] || [[ "$candidate" != "$self_path" ]]; then
			printf '%s\n' "$candidate"
			return 0
		fi
	fi

	for candidate in "$@"; do
		[[ -n "$candidate" ]] || continue
		if [[ -x "$candidate" ]]; then
			candidate="$(readlink -f "$candidate")"
			if [[ -z "$self_path" ]] || [[ "$candidate" != "$self_path" ]]; then
				printf '%s\n' "$candidate"
				return 0
			fi
		fi
	done

	return 1
}

ai::require_npm() {
	if ! command -v npm >/dev/null 2>&1; then
		echo "npm is required but was not found in PATH" >&2
		return 1
	fi
}

ai::ensure_uv() {
	if command -v uv >/dev/null 2>&1; then
		return 0
	fi

	curl -LsSf https://astral.sh/uv/install.sh | sh >&2
	ai::refresh_shell
	command -v uv >/dev/null 2>&1
}

ai::npm_install_latest() {
	local package_name="$1"
	ai::require_npm
	npm install -g "$package_name" >&2
	ai::refresh_shell
}

